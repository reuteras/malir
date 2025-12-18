#!/bin/bash

CONFIG_DIR="${HOME}/.config/manir"
PATH="${PATH}:/usr/libexec/docker/cli-plugins"
MALCOLM_VERSION="v25.12.1"
export PATH
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


# Function to update Ubuntu
function update-os(){
    info-message "Running apt update."
    # shellcheck disable=SC2024
    sudo apt update -qq > /dev/null 2>&1
    info-message "Running apt dist-upgrade."
    # shellcheck disable=SC2024
    while ! sudo DEBIAN_FRONTEND=noninteractive apt -y dist-upgrade --force-yes > /dev/null 2>&1 ; do
        info-message "APT busy. Will retry in 10 seconds."
        sleep 10
    done
    info-message "Running apt install to install needed packages."
    sudo DEBIAN_FRONTEND=noninteractive apt -y install apache2-utils ca-certificates curl openssl python3-dotenv python3-pretty-yaml > /dev/null 2>&1
    if which snap > /dev/null ; then
        info-message "Update snap."
        sudo snap refresh
    fi
    touch "${CONFIG_DIR}/os_done"
}


# Install Docker
function install-docker(){
    if dpkg --list | grep docker > /dev/null ; then
        touch "${CONFIG_DIR}/os_done"
    fi
    sudo install -m 0755 -d /etc/apt/keyrings > /dev/null 2>&1
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc > /dev/null 2>&1
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # shellcheck disable=SC1091
    echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update > /dev/null 2>&1
    info-message "Install Docker."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    touch "${CONFIG_DIR}/docker_done"
}

# Function to configure Malcolm
function malcolm-configure() {
    info-message "Starting automatic configuration of Malcolm"
    cd ~/Malcolm || exit
    echo "n" | python3 scripts/install.py --defaults \
        --dark-mode true \
        --extracted-file-server true \
        --extracted-file-server-password infected \
        --file-extraction all \
        --file-preservation quarantined \
        --file-scan-rule-update true \
        --filebeat-tcp-expose true \
        --live-capture-arkime false \
        --logstash-expose true \
        --malcolm-profile true \
        --netbox true \
        --opensearch-url http://opensearch:9200 \
        --auto-arkime true \
        --auto-freq true \
        --auto-oui true \
        --auto-suricata true \
        --auto-zeek true \
        --sftp-expose true \
        --suricata-rule-update true 
    touch nginx/htpasswd
    # shellcheck disable=SC2016
    python3 scripts/control.py --auth-noninteractive \
        --auth-admin-username admin \
        --auth-admin-password-htpasswd '$2y$05$N37mG4dLlQAHccESse3mL.6NGqLOqo/Vf5DpKoEmEeAL5mk8i15Ja' \
        --auth-admin-password-openssl '$1$RD8JxZlf$2aHwWP71GY3kKjMNfjIKu0' \
        --auth-generate-webcerts \
        --auth-generate-fwcerts
    info-message "Configuration of Malcolm done."
    touch "${CONFIG_DIR}/configure_done"
    info-message "Reboot to update settings. Then run the script install.sh again."
    exit
}


# Function to build Malcolm containers
function malcolm-build() {
    info-message "Starting build process for docker containers."
    info-message "This will take some time..."
    cd ~/Malcolm || exit
    if [[ -z ${MAXMIND_KEY} ]]; then
        # shellcheck disable=SC1091
        source "${HOME}/Malcolm/config/arkime-secret.env"
        MAXMIND_KEY="${MAXMIND_GEOIP_DB_LICENSE_KEY}"
        if [[ -z ${MAXMIND_KEY} ]]; then
            malcolm-maxmind
        fi
    fi
    if [[ "$1" == "" ]]; then 
        for image in $(grep -E "^  [a-z-]+:" ../Malcolm/docker-compose.yml | grep -vE "(default|-live)" | tr -d ' :') ; do
            echo "N" | MAXMIND_GEOIP_DB_LICENSE_KEY="${MAXMIND_KEY}" ZEEK_DEB_ALTERNATE_DOWNLOAD_URL=https://malcolm.fyi/zeek ./scripts/build.sh ./docker-compose-dev.yml "$image"
        done
    fi
    echo "N" | MAXMIND_GEOIP_DB_LICENSE_KEY="${MAXMIND_KEY}" ZEEK_DEB_ALTERNATE_DOWNLOAD_URL=https://malcolm.fyi/zeek ./scripts/build.sh ./docker-compose-dev.yml "$@"
    info-message "Build done."
    read -rp "Verify build status above. If it failed type 'exit' (otherwise hit enter): " dummy
    if [[ ${dummy} == "exit" ]]; then
        exit
    fi
    touch "${CONFIG_DIR}/build_done"
}


# Function to set MaxMind GeoIP license key for Arkime
function malcolm-maxmind() {
    info-message "The build process needs your Maxmind API Key (free)"
    info-message "Get it from https://www.maxmind.com/"
    echo ""
    cd ~/Malcolm || exit
    MAXMIND_KEY=""
    while [[ -z "${MAXMIND_KEY}" ]]; do
        read -rp "Maxmind GeoIP license key (will echo key): " MAXMIND_KEY
    done
    export MAXMIND_KEY
    echo ""
    sed -i -e "s/MAXMIND_GEOIP_DB_LICENSE_KEY=0/MAXMIND_GEOIP_DB_LICENSE_KEY=$MAXMIND_KEY/" config/arkime-secret.env
    if grep "MAXMIND_GEOIP_DB_LICENSE_KEY : '0'" config/arkime-secret.env > /dev/null 2>&1 ; then
        error-exit-message "Maxmind GeoIP License key not updated, exiting."
    fi
    touch "${CONFIG_DIR}/maxmind_done"
}


# Function to add intel from Critical Path Security to Zeek
function malcolm-zeek-intel(){
    info-message "Clone Zeek intel from Critical Path Security"
    CDIR="$(pwd)"
    cd ~/Malcolm/zeek/intel || exit
    git clone https://github.com/CriticalPathSecurity/Zeek-Intelligence-Feeds.git > /dev/null 2>&1
    cd ~/Malcolm || exit
    sed -i -e "s_/usr/local/zeek/share/zeek/site/Zeek-Intelligence-Feeds_/opt/zeek/share/zeek/site/intel/Zeek-Intelligence-Feeds_" zeek/intel/Zeek-Intelligence-Feeds/main.zeek
    cd "${CDIR}" || exit
    touch "${CONFIG_DIR}/zeek_intel_done"
}


# Change nginx configuration - add nfa
function nginx-configure(){
    info-message "Configure nginx."
    cd ~/Malcolm || exit
    sed -i -e "/  upstream upload/i \ \ upstream nfa {\n    server nfa:5001;\n  }\n" nginx/nginx.conf
    # shellcheck disable=SC2016
    sed -i -e '/    # Malcolm file upload/i \ \ \ \ # nfa\n    location ~* \/nfa\/(.*) {\n      proxy_pass http:\/\/nfa\/\$1;\n      proxy_redirect off;\n      proxy_set_header Host nfa.malcolm.local;\n    }\n' nginx/nginx.conf
    touch "${CONFIG_DIR}/nginx_done"
}


# Function to change Arkime configuration
function malcolm-configure-arkime(){
    info-message "Configure Arkime"
    cd ~/Malcolm || exit
    sed -i -e "s/magicMode=basic/magicMode=both/" arkime/etc/config.ini
    sed -i -e "s/parseDNSRecordAll=false/parseDNSRecordAll=true/" arkime/etc/config.ini
    sed -i -e "s/parseHTTPHeaderRequestAll=false/parseHTTPHeaderRequestAll=true/" arkime/etc/config.ini
    sed -i -e "s/parseHTTPHeaderResponseAll=false/parseHTTPHeaderResponseAll=true/" arkime/etc/config.ini
    sed -i -e "s/parseQSValue=false/parseQSValue=true/" arkime/etc/config.ini
    sed -i -e "s/parseSMTPHeaderAll=false/parseSMTPHeaderAll=true/" arkime/etc/config.ini
    sed -i -e "s/supportSha256=false/supportSha256=true/" arkime/etc/config.ini
    sed -i -e "s/maxReqBody=.*/maxReqBody=0/" arkime/etc/config.ini
    sed -i -e "s/spiDataMaxIndices=.*/spiDataMaxIndices=10000/" arkime/etc/config.ini
    sed -i -e "s/valueAutoComplete=false/valueAutoComplete=true/" arkime/etc/config.ini
    sed -i -e "s_# implicit.*_includes=/opt/arkime/etc/config-local.ini_" arkime/etc/config.ini
    cp ~/malir/resources/config-local.ini arkime/etc
    touch "${CONFIG_DIR}/arkime_done"
}


function add-nfa(){
    info-message "Add nfa"
    cd ~/Malcolm || exit
    [[ -d nfa ]] || git clone https://github.com/reuteras/nfa.git > /dev/null
    cp ~/malir/resources/nfa-config.ini nfa/config.ini
    if ! grep "nfa:" docker-compose* > /dev/null 2>&1 ; then
        sed -i "/services:/r ${HOME}/malir/resources/nfa-docker-compose.yml" docker-compose.yml
        sed -i "/services:/r ${HOME}/malir/resources/nfa-docker-compose-dev.yml" docker-compose-dev.yml
    fi
    touch "${CONFIG_DIR}/nfa_done"
}

# End of functions

# Create directory for status of installation and setup
info-message "Start installation of Malcolm and extra tools."
test -d "${CONFIG_DIR}" || mkdir -p "${CONFIG_DIR}"


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
if !  test -d Malcolm ; then
    git clone https://github.com/idaholab/Malcolm.git > /dev/null
    cd Malcolm || exit
    git fetch --all --tags
    info-message "Using version $MALCOLM_VERSION of Malcolm."
    git checkout tags/"$MALCOLM_VERSION" 2>&1 | grep Note
fi

test -e "${CONFIG_DIR}/os_done" || update-os
test -e "${CONFIG_DIR}/docker_done" || install-docker
test -e "${CONFIG_DIR}/configure_done" || malcolm-configure
test -e "${CONFIG_DIR}/maxmind_done" || malcolm-maxmind
test -e "${CONFIG_DIR}/zeek_intel_done" || malcolm-zeek-intel
test -e "${CONFIG_DIR}/arkime_done" || malcolm-configure-arkime
test -e "${CONFIG_DIR}/nginx_done" || nginx-configure
test -e "${CONFIG_DIR}/nfa_done" || add-nfa
test -e "${CONFIG_DIR}/build_done" || malcolm-build "$@"

info-message "Installation done."
info-message "Start Malcolm by changing to the ~/Malcolm directory and run ./scripts/start."
