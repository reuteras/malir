#!/bin/bash

CONFIG_DIR="${HOME}/.config/mir-script"

#
# Functions
# 

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

# Function to configure Malcolm
function malcolm-configure() {
    info-message "Starting interactive configuration of Malcolm"
    sudo python3 scripts/install.py
    python3 scripts/install.py --configure
    info-message "Configuration done."
    touch "${CONFIG_DIR}/configure_done"
    info-message "Reboot to update settings. Then run the script again."
    exit
}

# Function to build Malcolm
function malcolm-build() {
    info-message "Starting build process for docker containers."
    info-message "This will take some time..."
    ./scripts/build.sh
    info-message "Build done."
    touch "${CONFIG_DIR}/build_done"
}

# Function to set MaxMind GeoIP license key
function malcolm-maxmind() {
    info-message "The build process needs your Maxmind API Key"
    info-message "Go to https://www.maxmind.com/"
    echo ""
    read -sp "Maxmind GeoIP license key: " MAXMIND_KEY
    sed -i -e "s/MAXMIND_GEOIP_DB_LICENSE_KEY : '0'/MAXMIND_GEOIP_DB_LICENSE_KEY : \'$MAXMIND_KEY\'/" docker-compose.yml
    if grep "MAXMIND_GEOIP_DB_LICENSE_KEY : '0'" docker-compose.yml > /dev/null 2&>1 ; then
        echo "Maxmind GeoIP License key not updated, exiting."
        exit
    fi
    touch "${CONFIG_DIR}/maxmind_done"
}

function malcolm-authentication() {
    info-message "Start authentication setup." 
    ./scripts/auth_setup
    info-message "Authentication done." 
    touch "${CONFIG_DIR}/authentication_done"
}

# End of functions

# Create directory for status of installation and setup
test -d "${CONFIG_DIR}" || mkdir -p "${CONFIG_DIR}"

# Check for membership in group docker
if ! id | grep docker > /dev/null; then
    info-message "Add current user to group docker."
    grep docker: /etc/group > /dev/null 2>&1 || sudo groupadd docker
    sudo usermod -aG docker "$USER" || exit
    info-message "Logout and back in again to update group memberships."
    exit
fi

# Checkout Malcolm in home dir
cd "${HOME}" || exit
test -d Malcolm || git clone https://github.com/cisagov/Malcolm.git
cd Malcolm || exit

test -e "${CONFIG_DIR}/configure_done" || malcolm-configure
test -e "${CONFIG_DIR}/maxmind_done" || malcolm-maxmind
test -e "${CONFIG_DIR}/build_done" || malcolm-build
test -e "${CONFIG_DIR}/authentication_done" || malcolm-authentication

info-message "Installation done."
info-message "Start Malcolm by running ./script/start in the ~/Malcolm directory."
