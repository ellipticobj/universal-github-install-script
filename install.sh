#!/bin/bash

# ensure script exits on errors
set -euo pipefail

# installer script
# this downloads a github release executable for the current arch and installs it to the /usr/bin/ directory
#
# repo details:
# https://github.com/REPO_OWNER/REPO_NAME should be the repository you want to download the executable from
# EXECUTABLE_NAME_HERE should be the name of the executable that the user will install

# credits: https://github.com/ellipticobj
# to user: USE WITH CAUTION! THIS SCRIPT CAN BE MODIFIED TO BE DANGEROUS. ALWAYS CHECK THE SCRIPT BEFORE RUNNING IT.

# ------------------------------------
# init variables
# ------------------------------------
REPO_OWNER="ellipticobj"
REPO_NAME="cuter"
EXEC_NAME="cuter"
MIN_SIZE=100000

# ------------------------------------
# helpers
# ------------------------------------

build() {
    INSTALL_PATH="/usr/bin/"
    pip3 install -U PyInstaller

    echo "purging ./dist/"
    rm -rf dist/

    curl -fsSL "https://raw.githubusercontent.com/ellipticobj/cuter/refs/heads/v2/client.py" > client.py

    # single pyinstaller command with all necessary parameters
    python3 -m PyInstaller \
        --onefile \
        --name "$EXEC_NAME-$(uname -m)" \
        --clean \
        --upx-dir=/usr/bin \
        --exclude-module tkinter \
        --exclude-module unittest \
        --exclude-module pytest \
        --optimize 2 \
        client.py

    echo -e "\nexecutable size: \n$(du -sh "dist/$EXEC_NAME-$(uname -m)")"

    # determine install path based on architecture
    if [[ "$(uname -m)" == "arm64" ]]; then
        INSTALL_PATH='/usr/local/bin/'
    else
        INSTALL_PATH='/usr/bin/'
    fi

    echo -e "\nmove to ${INSTALL_PATH} (ENTER) or exit (anything else)?"
    read -r CONTINUE < /dev/tty
    if [ -n "${CONTINUE}" ]; then
        echo "build at dist/$EXEC_NAME-$(uname -m)"
        exit 0
    fi

    sudo mv "./dist/$EXEC_NAME-$(uname -m)" "$INSTALL_PATH$EXEC_NAME"

    echo "$EXEC_NAME installed to $INSTALL_PATH"

}

# ensures that the script exits immediately if an error occurs
set -euo pipefail

# ------------------------------------
# environment checks
# ------------------------------------
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    linux|darwin) ;;
    *) echo "error: unsupported os"; exit 1 ;;
esac

# set install path based on OS
if [[ "$OS" == "darwin" ]]; then
    INSTALL_PATH="/usr/local/bin/"
else
    INSTALL_PATH="/usr/bin/"
fi

# check for dependencies (curl, grep and sed)
for cmd in curl grep sed; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "error: $cmd is not installed."
        exit 1
    fi
done

# use jq if available
if command -v jq >/dev/null 2>&1; then
    USE_JQ=true
else
    USE_JQ=false
fi

# arch detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    arm64) ARCH="arm64" ;;
    aarch64) ARCH="aarch64" ;;
    *) echo "error: unsupported arch: $ARCH"; exit 1 ;;
esac

# ------------------------------------
# user confirmation
# ------------------------------------
# tells the user what this script does
echo "this script gets the executable from ./dist/ and installs it to ${INSTALL_PATH}"
echo "note: you may be prompted to input your password. this is to move the executable to ${INSTALL_PATH}"
echo "do you want to install?"
echo -n "enter y to continue or any other key to exit "
read CONTINUE
if [ "$CONTINUE" != "y" ]; then
    echo "exiting..."
    exit 0
fi

# ------------------------------------
# installation
# ------------------------------------
# get latest release tag
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
if command -v jq >/dev/null 2>&1; then
    LATEST=$(curl -s "$API_URL" | jq -r '.tag_name')
else
    LATEST=$(curl -s "$API_URL" | grep -oP '"tag_name": "\K[^"]+')
fi

[ -n "$LATEST" ] || { echo "failed to fetch release"; exit 1; }

# download executable
DOWNLOAD_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${LATEST}/${EXEC_NAME}-${ARCH}"
echo "downloading: $DOWNLOAD_URL"
curl -L -o "$EXEC_NAME" "$DOWNLOAD_URL" || { echo "download failed"; exit 1; }

# validate file size
file_size=$(wc -c < "$EXEC_NAME")
if (( file_size < MIN_SIZE )); then
    echo "error: no build available for your device"
    rm -f "$EXEC_NAME"
    echo "attempting to build locally"
    build
    exit 1
fi

# install
chmod +x "$EXEC_NAME"
sudo mv "$EXEC_NAME" "${INSTALL_PATH}${EXEC_NAME}"
echo "installed to ${INSTALL_PATH}${EXEC_NAME} yippie"
echo "run sigma to get started"
