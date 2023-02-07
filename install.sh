#!/bin/bash

CONFIG_DIR="${HOME}/.config/manir"
export DEBIAN_FRONTEND=noninteractive

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

# Turn off sound on start up
 function turn-off-sound() {
    if [[ ! -e /usr/share/glib-2.0/schemas/50_unity-greeter.gschema.override ]]; then
	info-message "Turn off sound."
        echo -e '[com.canonical.unity-greeter]\nplay-ready-sound = false' | \
        sudo tee -a /usr/share/glib-2.0/schemas/50_unity-greeter.gschema.override > /dev/null
        sudo glib-compile-schemas /usr/share/glib-2.0/schemas/
    fi
    touch "${CONFIG_DIR}/sound_done"
}

# Install docker.io and docker-compose
 function install-docker() {
	info-message "Install docker.io and docker-compose."
    sudo apt install -yqq docker.io docker-compose > /dev/null 2>&1
    touch "${CONFIG_DIR}/docker_done"
}

function update-ubuntu(){
    info-message "Running apt update."
    # shellcheck disable=SC2024
    sudo apt update -qq > /dev/null 2>&1
    info-message "Running apt dist-upgrade."
    # shellcheck disable=SC2024
    while ! sudo DEBIAN_FRONTEND=noninteractive apt -y dist-upgrade --force-yes > /dev/null 2>&1 ; do
        info-message "APT busy. Will retry in 10 seconds."
        sleep 10
    done
    touch "${CONFIG_DIR}/ubuntu_done"
}

# Install Google Chrome
function install-google-chrome() {
    if ! dpkg --status google-chrome-stable > /dev/null 2>&1 ; then
        info-message "Installing Google Chrome."
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        # shellcheck disable=SC2024
        sudo dpkg -i google-chrome-stable_current_amd64.deb > /dev/null 2>&1 || true
        # shellcheck disable=SC2024
        sudo apt -qq -f -y install > /dev/null 2>&1
        rm -f google-chrome-stable_current_amd64.deb
    fi
    info-message "Adding Google Chrome to favorites."
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'google-chrome.desktop']"
    touch "${CONFIG_DIR}/google_done"
}

# Function to configure Malcolm
function malcolm-configure() {
    info-message "Starting interactive configuration of Malcolm"
    cd ~/Malcolm || exit
    sudo python3 scripts/install.py
    python3 scripts/install.py --configure
    ./scripts/auth_setup
    sed -i -e "s/EXTRACTED_FILE_HTTP_SERVER_ENABLE : 'false'/EXTRACTED_FILE_HTTP_SERVER_ENABLE : 'true'/" docker-compose.yml
    sed -i -e "s/EXTRACTED_FILE_HTTP_SERVER_ENCRYPT : 'true'/EXTRACTED_FILE_HTTP_SERVER_ENCRYPT : 'false'/" docker-compose.yml
    info-message "Configuration done."
    touch "${CONFIG_DIR}/configure_done"
    info-message "Reboot to update settings. Then run the script again."
    exit
}

# Function to build Malcolm
function malcolm-build() {
    info-message "Starting build process for docker containers."
    info-message "This will take some time..."
    cd ~/Malcolm || exit
    ./scripts/build.sh
    info-message "Build done."
    read -rp "Verify build status above. If it failed type 'exit' (otherwise hit enter): " dummy
    if [[ ${dummy} == "exit" ]]; then
        exit
    fi
    touch "${CONFIG_DIR}/build_done"
}

# Function to set MaxMind GeoIP license key
function malcolm-maxmind() {
    info-message "The build process needs your Maxmind API Key"
    info-message "Go to https://www.maxmind.com/"
    echo ""
    cd ~/Malcolm || exit
    MAXMIND_KEY=""
    while [[ -z "${MAXMIND_KEY}" ]]; do
        read -rp "Maxmind GeoIP license key (will echo key): " MAXMIND_KEY
    done
    echo ""
    sed -i -e "s/MAXMIND_GEOIP_DB_LICENSE_KEY : '0'/MAXMIND_GEOIP_DB_LICENSE_KEY : \'$MAXMIND_KEY\'/" docker-compose.yml
    if grep "MAXMIND_GEOIP_DB_LICENSE_KEY : '0'" docker-compose.yml > /dev/null 2>&1 ; then
        error-exit-message "Maxmind GeoIP License key not updated, exiting."
    fi
    touch "${CONFIG_DIR}/maxmind_done"
}

function malcolm-docker-compose() {
    info-message "Increase retries in docker-compose.yml"
    sed -i -e "s/retries: 3$/retries: 40/" ~/Malcolm/docker-compose.yml
    info-message "Done increasing retries in docker-compose.yml"
    touch "${CONFIG_DIR}/docker_compose_done"
}

function malcolm-authentication() {
    info-message "Start authentication setup." 
    cd ~/Malcolm || exit
    ./scripts/auth_setup
    info-message "Authentication done." 
    touch "${CONFIG_DIR}/authentication_done"
}

function malcolm-background() {
    info-message "Set background." 
    gsettings set org.gnome.desktop.background picture-uri "file:///home/${USER}/manir/resources/bg.jpg"
    touch "${CONFIG_DIR}/background_done"
}

function malcolm-zeek-intel(){
    info-message "Clone Zeek intel from Critical Path Security"
    CDIR="$(pwd)"
    cd ~/Malcolm/zeek/intel || exit
    git clone https://github.com/CriticalPathSecurity/Zeek-Intelligence-Feeds.git
    cd ~/Malcolm || exit   
    sed -i -e "s_/usr/local/zeek/share/zeek/site/Zeek-Intelligence-Feeds_/opt/zeek/share/zeek/site/intel/Zeek-Intelligence-Feeds_" zeek/intel/Zeek-Intelligence-Feeds/main.zeek
    cd "${CDIR}" || exit
    touch "${CONFIG_DIR}/zeek_intel_done"
}

function nginx-configure(){
    info-message "Configure nginx."
    cd ~/Malcolm || exit
    sed -i -e "/  upstream upload/i \ \ upstream arkime-wise {\n    server arkime:8081;\n  }\n" nginx/nginx.conf
    sed -i -e "/    # Malcolm file upload/i \ \ \ \ # Arkime wise\n    location ~* \/wise\/(.*) {\n      proxy_pass http:\/\/arkime-wise\/\$1;\n      proxy_redirect off;\n      proxy_set_header Host wise.malcolm.local;\n    }\n" nginx/nginx.conf
    touch "${CONFIG_DIR}/nginx_done"
}

function malcolm-configure-arkime(){
    info-message "Configure Arkime"
    cd ~/Malcolm || exit
    sed -i -e "s/parseQSValue=false/parseQSValue=true/" arkime/etc/config.ini
    sed -i -e "s/supportSha256=false/supportSha256=true/" arkime/etc/config.ini
    sed -i -e "s/maxReqBody=64/maxReqBody=1024/" arkime/etc/config.ini
    sed -i -e "s/spiDataMaxIndices=7/spiDataMaxIndices=10000/" arkime/etc/config.ini
    sed -i -e "s_# implicit.*_includes=/opt/arkime/etc/config-local.ini_" arkime/etc/config.ini
    sed -i -e "s/--insecure/--insecure --webconfig/" arkime/scripts/wise_service.sh
    cp ~/malir/resources/config-local.ini arkime/etc
    touch "${CONFIG_DIR}/arkime_done"
}

# End of functions

# Create directory for status of installation and setup
info-message "Start installation of Malcolm and exta tools."
test -d "${CONFIG_DIR}" || mkdir -p "${CONFIG_DIR}"

if ! gsettings get org.gnome.shell favorite-apps | grep "org.gnome.Terminal.desktop" > /dev/null ; then
    info-message "Add Terminal to favorite apps."
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'org.gnome.Terminal.desktop']"
fi

# Check for membership in group docker
if ! grep "docker:" /etc/group | grep -E "(,|:)${USER}" > /dev/null; then
    info-message "Add current user to group docker."
    grep docker: /etc/group > /dev/null 2>&1 || sudo groupadd docker
    sudo usermod -aG docker "$USER" || exit
    info-message "Logout and back in again to update group memberships."
    exit
fi

# Checkout Malcolm in home dir
cd "${HOME}" || exit
test -d Malcolm || git clone https://github.com/cisagov/Malcolm.git

if [[ "$(uname -m)" == "aarch64" && ! -f "${CONFIG_DIR}/aarch64_done" ]]; then
    info-message "Fixes for aarch64"
    cd ~/Malcolm || exit
    cp ~/malir/aarch64/*Dockerfile "${HOME}"/Malcolm/Dockerfiles
    sed -i -e "s/amd64/arm64/" scripts/install.py
    touch "${CONFIG_DIR}/aarch64_done"
fi

test -e "${CONFIG_DIR}/ubuntu_done" || update-ubuntu
test -e "${CONFIG_DIR}/google_done" || install-google-chrome
test -e "${CONFIG_DIR}/sound_done" || turn-off-sound
test -e "${CONFIG_DIR}/docker_done" || install-docker
test -e "${CONFIG_DIR}/configure_done" || malcolm-configure
test -e "${CONFIG_DIR}/maxmind_done" || malcolm-maxmind
test -e "${CONFIG_DIR}/docker_compose_done" || malcolm-docker-compose
test -e "${CONFIG_DIR}/zeek_intel_done" || malcolm-zeek-intel
test -e "${CONFIG_DIR}/arkime_done" || malcolm-configure-arkime
test -e "${CONFIG_DIR}/nginx_done" || nginx-configure
test -e "${CONFIG_DIR}/build_done" || malcolm-build
test -e "${CONFIG_DIR}/authentication_done" || malcolm-authentication
test -e "${CONFIG_DIR}/background_done" || malcolm-background

info-message "Installation done."
info-message "Start Malcolm by running ./scripts/start in the ~/Malcolm directory."
