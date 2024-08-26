#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NO_COLOR='\033[0m'

# Define animation frames
SPINNER=("⠁" "⠉" "⠙" "⠹" "⠽" "⠿")

# Declare patch files based on architecture
declare -A PATCH_FILES=(
    ["aarch64"]="/usr/src/incubator-pagespeed-mod-aarch64.patch"
    ["armv7l"]="/usr/src/incubator-pagespeed-mod-armv7l.patch"
    ["x86_64"]="/usr/src/incubator-pagespeed-mod-x86_64.patch"
)

# Get current architecture and glibc version
ARCH=$(uname -m)
GLIBC_VERSION=$(ldd --version | awk 'NR==1 {print $NF}')
GLIBC_VERSION_NUMBER=$(awk -F. '{print $1 * 100 + $2}' <<< "$GLIBC_VERSION")

# Apply the appropriate patch
PATCH_FILE="${PATCH_FILES[$ARCH]}"
if [[ -n "$PATCH_FILE" ]]; then
    printf "${CYAN}Applying patch for $ARCH...${NO_COLOR}\n"
    patch -Np1 -i "$PATCH_FILE"
else
    printf "${RED}Unsupported architecture: $ARCH${NO_COLOR}\n"
    exit 1
fi

# Check glibc version and apply sed command if necessary
if [[ "$GLIBC_VERSION_NUMBER" -ge 228 ]]; then
    printf "${CYAN}glibc version $GLIBC_VERSION detected. Applying sed command...${NO_COLOR}\n"
    sed -i 's/sys_siglist\[signum\]/strsignal(signum)/g' /usr/src/incubator-pagespeed-mod/third_party/apr/src/threadproc/unix/signals.c
else
    printf "${YELLOW}glibc version $GLIBC_VERSION detected. No sed command applied.${NO_COLOR}\n"
fi

# Run the build and installation scripts
printf "${GREEN}Running build and installation scripts...${NO_COLOR}\n"
python /usr/src/incubator-pagespeed-mod/build/gyp_chromium --depth=/usr/src/incubator-pagespeed-mod

# Run the build_psol.sh script in the background
/usr/src/incubator-pagespeed-mod/install/build_psol.sh --skip_tests > /dev/null 2>&1 &
BUILD_PID=$!
START_TIME=$(date +%s)

# Print playful status message with spinner animation every 0.1 seconds until the process completes
while kill -0 "$BUILD_PID" 2> /dev/null; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    ELAPSED_HOURS=$((ELAPSED_TIME / 3600))
    ELAPSED_MINUTES=$(((ELAPSED_TIME % 3600) / 60))
    ELAPSED_SECONDS=$((ELAPSED_TIME % 60))
    
    # Calculate spinner frame
    FRAME_INDEX=$(( ELAPSED_TIME / 2 % ${#SPINNER[@]} ))
    
    # Print status with spinner
    printf "${YELLOW}Hang tight! ${NO_COLOR}Elapsed time: ${BLUE}%dh %dm %ds ${SPINNER[$FRAME_INDEX]}\r" \
        "$ELAPSED_HOURS" "$ELAPSED_MINUTES" "$ELAPSED_SECONDS"
    sleep 0.1  # Shorter sleep time for smoother animation
done

# Clear the line after the spinner stops
printf '\r'

# Check the exit status of the build process
if wait "$BUILD_PID"; then
    printf "${GREEN}Build and installation completed successfully.${NO_COLOR}\n"
    tar -xzf psol-1.15.0.0-*.tar.gz

    TAR_FILENAME="psol-1.15.0.0-${ARCH}-glibc-${GLIBC_VERSION}.tar.gz"
    if [[ -d /usr/src/incubator-pagespeed-mod/psol ]]; then
        tar -czf "/dist/$TAR_FILENAME" -C /usr/src/incubator-pagespeed-mod psol
        printf "${GREEN}Successfully created and moved $TAR_FILENAME.${NO_COLOR}\n"
    else
        printf "${RED}Directory /usr/src/incubator-pagespeed-mod/psol not found for compression.${NO_COLOR}\n"
        exit 1
    fi
    printf "${GREEN}Have fun with PAGESPEED.${NO_COLOR}\n"
else
    printf "${RED}Build and installation failed.${NO_COLOR}\n"
    exit 1
fi
