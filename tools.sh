#!/bin/bash

CONFIG_DIR="${HOME}/.config/manir"

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


# Install Google Chrome
function install-google-chrome() {
    if [[ "$(uname -m)" != "aarch64" ]]; then
        if ! dpkg --status google-chrome-stable > /dev/null 2>&1 ; then
            info-message "Installing Google Chrome."
            wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
            # shellcheck disable=SC2024
            sudo dpkg -i google-chrome-stable_current_amd64.deb > /dev/null 2>&1 || true
            # shellcheck disable=SC2024
            sudo apt -qq -f -y install > /dev/null 2>&1
            rm -f google-chrome-stable_current_amd64.deb
            info-message "Adding Google Chrome to favorites."
            gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'google-chrome.desktop']"
            xdg-settings set default-web-browser google-chrome.desktop
        fi
    else
        if ! dpkg --status chromium > /dev/null 2>&1 ; then
            info-message "Installing Chromium."
            if test -e /etc/os-release && grep "Debian GNU" /etc/os-release > /dev/null; then
                sudo apt install -yqq chromium > /dev/null 2>&1
                info-message "Adding Chromium to favorites and set default."
                gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'chromium.desktop']"
                xdg-settings set default-web-browser chromium.desktop
            else
                sudo apt install -yqq chromium-browser > /dev/null 2>&1
                info-message "Adding Chromium to favorites and set default."
                gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'chromium_chromium.desktop']"
                xdg-settings set default-web-browser chromium_chromium.desktop
            fi
        fi
    fi
    touch "${CONFIG_DIR}/google_done"
}


# Set different background
function malcolm-background() {
    info-message "Set background."
    gsettings set org.gnome.desktop.background picture-uri "file:///home/${USER}/manir/resources/bg.jpg"
    touch "${CONFIG_DIR}/background_done"
}


# Add terminal to favorite apps
if ! gsettings get org.gnome.shell favorite-apps | grep "org.gnome.Terminal.desktop" > /dev/null ; then
    info-message "Add Terminal to favorite apps."
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'org.gnome.Terminal.desktop']"
fi


info-message "Update apt."
sudo apt -qq update > /dev/null 2>&1
info-message "Install packages."
sudo apt install -y -qq \
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

test -e "${CONFIG_DIR}/google_done" || install-google-chrome
test -e "${CONFIG_DIR}/background_done" || malcolm-background
