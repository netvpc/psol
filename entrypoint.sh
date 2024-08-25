#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NO_COLOR='\033[0m'

# Define animation frames
SPINNER=("⠁" "⠉" "⠙" "⠹" "⠽" "⠿")

# Declare patch files based on architecture
declare -A PATCH_FILES=(
    ["aarch64"]="/usr/src/incubator-pagespeed-mod-aarch64.patch"
    ["armv7l"]="/usr/src/incubator-pagespeed-mod-armv7l.patch"
)

# Get current architecture
ARCH=$(uname -m)

# Apply the appropriate patch
PATCH_FILE="${PATCH_FILES[$ARCH]}"
if [[ -n "$PATCH_FILE" ]]; then
    echo -e "${CYAN}Applying patch for $ARCH...${NO_COLOR}"
    patch -Np1 -i "$PATCH_FILE"
elif [[ "$ARCH" == "x86_64" ]]; then
    echo -e "${YELLOW}x86_64 architecture detected. No patch applied.${NO_COLOR}"
else
    echo -e "${RED}Unsupported architecture: $ARCH${NO_COLOR}"
    exit 1
fi

# Check glibc version and apply sed command if necessary
GLIBC_VERSION=$(ldd --version | awk 'NR==1 {print $NF}')
GLIBC_VERSION_NUMBER=$(echo "$GLIBC_VERSION" | awk -F. '{print $1 * 100 + $2}')

if [[ "$GLIBC_VERSION_NUMBER" -ge 228 ]]; then
    echo -e "${CYAN}glibc version $GLIBC_VERSION detected. Applying sed command...${NO_COLOR}"
    sed -i 's/sys_siglist\[signum\]/strsignal(signum)/g' /usr/src/incubator-pagespeed-mod/third_party/apr/src/threadproc/unix/signals.c
else
    echo -e "${YELLOW}glibc version $GLIBC_VERSION detected. No sed command applied.${NO_COLOR}"
fi

# Run the build and installation scripts
echo -e "${GREEN}Running build and installation scripts...${NO_COLOR}"
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
    echo -ne "${YELLOW}Hang tight! ${MAGENTA}Maybe grab a coffee? ${NO_COLOR}Elapsed time: ${BLUE}${ELAPSED_HOURS}h ${ELAPSED_MINUTES}m ${ELAPSED_SECONDS}s ${SPINNER[$FRAME_INDEX]}\r"
    sleep 0.1  # Shorter sleep time for smoother animation
done

# Clear the line after the spinner stops
echo -ne '\r'

# Check the exit status of the build process
if wait "$BUILD_PID"; then
    echo -e "${GREEN}Build and installation completed successfully.${NO_COLOR}"
else
    echo -e "${RED}Build and installation failed.${NO_COLOR}"
    exit 1
fi
