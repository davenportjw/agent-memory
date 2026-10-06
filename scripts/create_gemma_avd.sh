#!/usr/bin/env bash
# ==============================================================================
# create_gemma_avd.sh
# Creates and tunes an ARM64 Android Virtual Device (AVD) optimized for
# running on Apple Silicon (macOS) with local Gemma 4 edge execution.
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
IMAGE="system-images;android-34;google_apis;arm64-v8a"
DEVICE_PROFILE="${2:-pixel_tablet}"

echo "==========================================================="
echo " ANTIGRAVITY // CREATING AVD: ${AVD_NAME}"
echo " Image: ${IMAGE}"
echo " Profile: ${DEVICE_PROFILE}"
echo "==========================================================="

if ! command -v avdmanager &> /dev/null; then
    echo "Error: avdmanager not found. Run scripts/setup_android_sdk.sh first."
    exit 1
fi

# Create AVD (silent echo 'no' to custom hardware prompt if prompted)
echo "no" | avdmanager create avd \
    --name "${AVD_NAME}" \
    --package "${IMAGE}" \
    --device "${DEVICE_PROFILE}" \
    --force

AVD_DIR="${HOME}/.android/avd/${AVD_NAME}.avd"
CONFIG_FILE="${AVD_DIR}/config.ini"

if [ -f "${CONFIG_FILE}" ]; then
    echo "==> Configuring hardware parameters for Gemma 4 INT4 execution..."
    # Helper to set or append config keys
    set_config() {
        local key="$1"
        local val="$2"
        if grep -q "^${key}=" "${CONFIG_FILE}"; then
            sed -i '' "s/^${key}=.*/${key}=${val}/" "${CONFIG_FILE}"
        else
            echo "${key}=${val}" >> "${CONFIG_FILE}"
        fi
    }

    # High RAM allocation (6144 MB) for Android OS + Gemma 4 INT4 weights (~1.2 GB)
    set_config "hw.ramSize" "6144"
    set_config "vm.heapSize" "1024"
    set_config "hw.gpu.enabled" "yes"
    set_config "hw.gpu.mode" "host"
    set_config "hw.keyboard" "yes"
    set_config "disk.dataPartition.size" "16G"
    set_config "hw.camera.back" "none"
    set_config "hw.camera.front" "none"
    set_config "hw.battery" "yes"

    echo "✔ Hardware configuration written to ${CONFIG_FILE}"
fi

echo ""
echo "==========================================================="
echo "✔ AVD CREATED SUCCESSFULLY: ${AVD_NAME}"
echo "  Launch with: bash scripts/run_android_emulator.sh ${AVD_NAME}"
echo "==========================================================="
