#!/bin/bash

echo "wireshark-common wireshark-common/install-setuid boolean true" | \
    sudo debconf-set-selections
export DEBIAN_FRONTEND=noninteractive

# Functions to print messages
function info-message() {
    echo "**** INFO: $*"
}

function error-message() {
    (>&2 echo "**** ERROR: $*")
}

function error-exit-message() {
    (>&2 echo "**** ERROR: $*")
        exit 1
}

info-message "Update apt."
sudo apt update > /dev/null 2>&1
info-message "Install packages."
sudo apt install -y -q \
    ascii \
    bless \
    bsdgames \
    dos2unix \
    exfat-fuse \
    git \
    jq \
    ngrep \
    p7zip \
    python3-yara \
    screen \
    sqlite3 \
    sqlitebrowser \
    strace \
    tcpslice \
    tmux \
    tshark \
    unrar \
    vim \
    vim-doc \
    vim-scripts \
    whois \
    wireshark \
    wswedish \
    yara \
    yara-doc \
    zip > /dev/null 2>&1

