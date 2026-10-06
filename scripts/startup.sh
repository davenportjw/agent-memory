#!/usr/bin/env bash
# ==============================================================================
# startup.sh // Antigravity Distributed AI Emulator & Client Launcher
#
# Launches the ARM64 Android Virtual Device tuned for on-device Gemma 4,
# connects to the live Cloud Run backend (Gemini 3.8 Flash), and launches
# the Flutter application.
#
# This script can be run from ANY folder in your terminal!
# ==============================================================================
set -euo pipefail

# 1. Self-locate root directory regardless of current working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "${SCRIPT_DIR}")" = "scripts" ]; then
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
    ROOT_DIR="${SCRIPT_DIR}"
fi

# 2. Source .env if present
if [ -f "${ROOT_DIR}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "${ROOT_DIR}/.env"
    set +a
fi

# 3. Environment & User Paths
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
export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:/usr/local/bin:/opt/homebrew/bin:${PATH}"

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

# Defaults
AVD_NAME="gemma4_edge_tablet"
CLOUD_BACKEND_URL="${CLOUD_BACKEND_URL:-http://localhost:8080}"
EMULATOR_ONLY=false
BUILD_ONLY=false
FORCE_REBUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --emulator-only)
            EMULATOR_ONLY=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --rebuild)
            FORCE_REBUILD=true
            shift
            ;;
        --avd)
            AVD_NAME="$2"
            shift 2
            ;;
        --cloud-url)
            CLOUD_BACKEND_URL="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./start_emulator.sh [options]"
            echo ""
            echo "Options:"
            echo "  --emulator-only       Boot the emulator without building or launching the Flutter app"
            echo "  --build-only          Build and install the Flutter app to an already-running emulator"
            echo "  --rebuild             Force a clean rebuild of the Flutter APK before running"
            echo "  --avd <name>          Specify AVD name (default: gemma4_edge_tablet)"
            echo "  --cloud-url <url>     Override live Cloud Run endpoint URL"
            echo "  -h, --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Run with --help for usage."
            exit 1
            ;;
    esac
done

echo "==========================================================="
echo " ANTIGRAVITY DISTRIBUTED AI // RUNTIME STARTUP"
echo " Working Root: ${ROOT_DIR}"
echo " AVD Target:   ${AVD_NAME}"
echo " Cloud Run:    ${CLOUD_BACKEND_URL}"
echo " Java Home:    ${JAVA_HOME:-system default}"
echo " Host Arch:    $(uname -m) (Apple Silicon)"
echo "==========================================================="

# Step 1: Ensure Android SDK & Command-Line Tools are present
if [ ! -d "${ANDROID_HOME}" ] || [ ! -f "${ANDROID_HOME}/emulator/emulator" ]; then
    echo ""
    echo "==> Android SDK or emulator not found at ${ANDROID_HOME}."
    echo "==> Running automated setup (scripts/setup_android_sdk.sh)..."
    bash "${ROOT_DIR}/scripts/setup_android_sdk.sh"
fi

# Step 2: Ensure the AVD exists
AVD_DIR="${ANDROID_AVD_HOME}/${AVD_NAME}.avd"
if [ ! -d "${AVD_DIR}" ]; then
    echo ""
    echo "==> Virtual device '${AVD_NAME}' not found."
    echo "==> Creating high-RAM ARM64 AVD for local Gemma 4 (scripts/create_gemma_avd.sh)..."
    bash "${ROOT_DIR}/scripts/create_gemma_avd.sh" "${AVD_NAME}"
fi

# Step 3: Probe live Cloud Run backend
echo ""
echo "==> Probing Cloud Run Backend (${CLOUD_BACKEND_URL}/health)..."
if curl -s -f -m 5 "${CLOUD_BACKEND_URL}/health" > /dev/null 2>&1; then
    echo "✔ Cloud Run backend is ONLINE (Gemini 3.8 Flash live)"
else
    echo "⚠ Cloud Run backend probe timed out or returned non-200. App will use offline circuit breaker if needed."
fi

# Step 4: Boot Android Emulator
if [ "${BUILD_ONLY}" = false ]; then
    echo ""
    RUNNING_DEVICE=$(adb devices 2>/dev/null | grep -E "emulator-[0-9]+" | awk '{print $1}' | head -n 1 || true)
    
    if [ -z "${RUNNING_DEVICE}" ]; then
        echo "==> Starting Android Emulator [${AVD_NAME}] in background..."
        emulator -avd "${AVD_NAME}" \
            -gpu host \
            -no-snapshot-load \
            -no-boot-anim \
            -netdelay none \
            -netspeed full &
        
        EMU_PID=$!
        echo "✔ Emulator launched with host Metal acceleration (PID: ${EMU_PID})"
        
        echo "==> Waiting for Android OS boot completion..."
        adb wait-for-device
        while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
            sleep 2
            echo "    ...waiting for Android OS boot"
        done
        echo "✔ Android OS booted and ready!"
    else
        echo "✔ Detected already running emulator: ${RUNNING_DEVICE}"
    fi
fi

if [ "${EMULATOR_ONLY}" = true ]; then
    echo ""
    echo "==========================================================="
    echo "✔ EMULATOR IS RUNNING (--emulator-only specified)"
    echo "==========================================================="
    exit 0
fi

# Step 5: Build Flutter Client APK
echo ""
APK_PATH="${ROOT_DIR}/client/build/app/outputs/flutter-apk/app-debug.apk"
if [ "${FORCE_REBUILD}" = true ] || [ ! -f "${APK_PATH}" ]; then
    echo "==> Building Flutter Android APK targeting Cloud Run..."
    cd "${ROOT_DIR}/client"
    bash "${ROOT_DIR}/scripts/flutter" build apk --debug \
        --dart-define="CLOUD_BACKEND_URL=${CLOUD_BACKEND_URL}"
else
    echo "✔ Found existing build at ${APK_PATH} (use --rebuild to recompile)"
fi

# Step 6: Install and Launch APK
echo ""
echo "==> Verifying Android device/emulator connection..."
DEVICE=$(adb devices 2>/dev/null | grep -E "emulator-[0-9]+" | awk '{print $1}' | head -n 1 || true)
if [ -z "${DEVICE}" ]; then
    echo "==> No active emulator detected in ADB table. Refreshing ADB server..."
    adb kill-server >/dev/null 2>&1 || true
    adb start-server >/dev/null 2>&1 || true
    sleep 2
    DEVICE=$(adb devices 2>/dev/null | grep -E "emulator-[0-9]+" | awk '{print $1}' | head -n 1 || true)
fi

if [ -z "${DEVICE}" ]; then
    echo "⚠ Waiting for emulator to connect to ADB (adb wait-for-device)..."
    adb wait-for-device
fi

echo "==> Waiting for Android OS boot completion..."
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    sleep 2
done
echo "✔ Emulator OS ready!"

echo "==> Installing APK to emulator..."
adb install -r "${APK_PATH}"

echo "==> Launching Antigravity Distributed AI on emulator screen..."
adb shell am start -n com.example.client/.MainActivity

echo ""
echo "==========================================================="
echo "🎉 APPLICATION RUNNING IN EMULATOR"
echo "  • Edge Engine:  Gemma 4 INT4 (Local, 0 KB Egress)"
echo "  • Cloud Engine: Gemini 3.8 Flash (Live Cloud Run)"
echo "  • Workspace:    Academic Sepia 3-Panel Layout"
echo "==========================================================="
