#!/usr/bin/env bash
# ==============================================================================
# run_android_emulator.sh
# Boots the ARM64 Android Virtual Device, waits for boot completion,
# builds the Flutter Android app with live Cloud Run backend integration,
# installs and launches the app on the emulated device.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source .env if present
if [ -f "${ROOT_DIR}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/.env"
    set +a
fi

# Auto-detect real user home (avoid .tmp_home from local flutter sdk wrapper)
REAL_USER_HOME="${HOME}"
if [[ "${REAL_USER_HOME}" == *".tmp_home"* ]] || [ -z "${REAL_USER_HOME}" ]; then
    CURRENT_USER="$(id -un 2>/dev/null || whoami 2>/dev/null || echo "")"
    if [ -n "${CURRENT_USER}" ] && [ -d "/Users/${CURRENT_USER}" ]; then
        REAL_USER_HOME="/Users/${CURRENT_USER}"
    elif [ -n "${CURRENT_USER}" ] && [ -d "/home/${CURRENT_USER}" ]; then
        REAL_USER_HOME="/home/${CURRENT_USER}"
    fi
fi

export ANDROID_HOME="${ANDROID_HOME:-${REAL_USER_HOME}/Library/Android/sdk}"
export ANDROID_AVD_HOME="${REAL_USER_HOME}/.android/avd"
export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:${PATH}"

# Auto-detect & enforce Java 21/17 LTS (Gradle 8 & AGP do not support Java 25+)
CURRENT_JAVA_MAJOR=""
if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
    CURRENT_JAVA_MAJOR="$("${JAVA_HOME}/bin/java" -version 2>&1 | sed -E -n 's/.*version "([0-9]+).*/\1/p')"
elif command -v java >/dev/null 2>&1; then
    CURRENT_JAVA_MAJOR="$(java -version 2>&1 | sed -E -n 's/.*version "([0-9]+).*/\1/p')"
fi

if [ -z "${CURRENT_JAVA_MAJOR}" ] || [ "${CURRENT_JAVA_MAJOR}" -gt 21 ] 2>/dev/null; then
    if [ -d "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
        export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    elif [ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
        export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    fi
fi
if [ -n "${JAVA_HOME:-}" ]; then
    export PATH="${JAVA_HOME}/bin:${PATH}"
fi

AVD_NAME="${1:-gemma4_edge_tablet}"
CLOUD_BACKEND_URL="${2:-${CLOUD_BACKEND_URL:-http://localhost:8080}}"

echo "==========================================================="
echo " ANTIGRAVITY // ANDROID EMULATOR RUNTIME LAUNCHER"
echo " AVD Target: ${AVD_NAME}"
echo " Cloud Run Backend: ${CLOUD_BACKEND_URL}"
echo "==========================================================="

# 1. Verify adb is available
if ! command -v adb &> /dev/null; then
    echo "Error: adb command not found. Run scripts/setup_android_sdk.sh first."
    exit 1
fi

# 2. Check if an emulator or device is already connected
RUNNING_DEVICE=$(adb devices | grep -E "emulator-[0-9]+" | awk '{print $1}' | head -n 1 || true)

if [ -z "${RUNNING_DEVICE}" ]; then
    echo "==> Launching Android Emulator [${AVD_NAME}]..."
    if ! command -v emulator &> /dev/null; then
        echo "Error: emulator binary not found in PATH or ${ANDROID_HOME}/emulator."
        exit 1
    fi
    
    # Launch emulator with Metal-backed host GPU acceleration
    emulator -avd "${AVD_NAME}" \
        -gpu host \
        -no-snapshot-load \
        -no-boot-anim \
        -netdelay none \
        -netspeed full &
    
    EMU_PID=$!
    echo "✔ Emulator process started (PID: ${EMU_PID})"
else
    echo "✔ Existing running emulator detected: ${RUNNING_DEVICE}"
fi

# 3. Wait for device to finish booting
echo "==> Waiting for Android OS boot completion..."
adb wait-for-device
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    sleep 2
    echo "    ...waiting for sys.boot_completed"
done
echo "✔ Android OS boot complete!"

# 4. Build Flutter Android APK targeting live Cloud Run instance
echo "==> Building Flutter Android APK with Cloud Run endpoint..."
cd "${ROOT_DIR}/client"
bash "${ROOT_DIR}/scripts/flutter" build apk --debug \
    --dart-define="CLOUD_BACKEND_URL=${CLOUD_BACKEND_URL}"

APK_PATH="${ROOT_DIR}/client/build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "${APK_PATH}" ]; then
    echo "Error: APK not found at ${APK_PATH}"
    exit 1
fi

# 5. Install and launch on emulator
echo "==> Installing APK to emulator..."
adb install -r "${APK_PATH}"

echo "==> Launching Antigravity Distributed AI on device..."
adb shell am start -n com.example.client/.MainActivity

echo ""
echo "==========================================================="
echo "✔ APPLICATION RUNNING ON ANDROID EMULATOR"
echo "  Cloud Instance: ${CLOUD_BACKEND_URL}"
echo "  Edge Engine: Gemma 4 INT4 (Local)"
echo "==========================================================="
