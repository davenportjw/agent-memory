#!/usr/bin/env bash
# ==============================================================================
# setup_android_sdk.sh
# Sets up Android SDK Command-Line Tools, Platform Tools, System Image (ARM64),
# and Emulator for Apple Silicon macOS, then links to Flutter.
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
export ANDROID_SDK_ROOT="${ANDROID_HOME}"
CMDLINE_TOOLS_DIR="${ANDROID_HOME}/cmdline-tools/latest"

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

echo "==========================================================="
echo " ANTIGRAVITY // ANDROID SDK & TOOLCHAIN SETUP"
echo " Host OS: Darwin arm64 (Apple Silicon)"
echo " Android Home: ${ANDROID_HOME}"
echo " Java Home:    ${JAVA_HOME:-system default}"
echo "==========================================================="

mkdir -p "${ANDROID_HOME}/cmdline-tools"
mkdir -p "${HOME}/.android"
touch "${HOME}/.android/repositories.cfg"

# 1. Download official Android Command-Line Tools if not already installed
if [ ! -f "${CMDLINE_TOOLS_DIR}/bin/sdkmanager" ]; then
    echo "==> Downloading official Android SDK Command-Line Tools..."
    TMP_ZIP="/tmp/cmdline-tools-mac.zip"
    curl -fSL "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip" -o "${TMP_ZIP}"

    echo "==> Extracting to ${ANDROID_HOME}/cmdline-tools..."
    TMP_EXTRACT="/tmp/cmdline-tools-extract"
    rm -rf "${TMP_EXTRACT}"
    mkdir -p "${TMP_EXTRACT}"
    unzip -q -o "${TMP_ZIP}" -d "${TMP_EXTRACT}"

    rm -rf "${CMDLINE_TOOLS_DIR}"
    mv "${TMP_EXTRACT}/cmdline-tools" "${CMDLINE_TOOLS_DIR}"
    rm -f "${TMP_ZIP}"
    rm -rf "${TMP_EXTRACT}"
    echo "✔ Android Command-Line Tools installed at ${CMDLINE_TOOLS_DIR}"
else
    echo "✔ Android Command-Line Tools already present."
fi

export PATH="${CMDLINE_TOOLS_DIR}/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:${PATH}"

# 2. Accept SDK licenses
echo "==> Accepting Android SDK licenses..."
yes | sdkmanager --sdk_root="${ANDROID_HOME}" --licenses > /dev/null 2>&1 || true

# 3. Install Platform-Tools, API 34 Platform, ARM64 System Image, and Emulator
echo "==> Installing Android Platform 34, ARM64 System Image, and Emulator..."
sdkmanager --sdk_root="${ANDROID_HOME}" \
    "platform-tools" \
    "platforms;android-34" \
    "system-images;android-34;google_apis;arm64-v8a" \
    "emulator"

# 4. Link Android SDK with Flutter
echo "==> Configuring Flutter SDK to target ${ANDROID_HOME}..."
bash "${ROOT_DIR}/scripts/flutter" config --android-sdk "${ANDROID_HOME}"

echo ""
echo "==========================================================="
echo "✔ ANDROID SDK SETUP COMPLETE"
echo "  Path: ${ANDROID_HOME}"
echo "  adb:  $(which adb || echo "${ANDROID_HOME}/platform-tools/adb")"
echo "==========================================================="
