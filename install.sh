#!/bin/bash

CONFIG_DIR="${HOME}/.config/manir"
PATH="${PATH}:/usr/libexec/docker/cli-plugins"
MALCOLM_VERSION="v24.02.0"
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
    info-message "Running apt install to install needed packages."
    sudo DEBIAN_FRONTEND=noninteractive apt -y install apache2-utils openssl python3-dotenv python3-pretty-yaml > /dev/null 2>&1
    if which snap > /dev/null ; then
        info-message "Update snap."
        sudo snap refresh
    fi
    touch "${CONFIG_DIR}/ubuntu_done"
}


# Function to configure Malcolm
function malcolm-configure() {
    info-message "Starting automatic configuration of Malcolm"
    cd ~/Malcolm || exit
    echo "n" | sudo python3 scripts/install.py --defaults \
        --dark-mode true \
        --extracted-file-server true \
        --extracted-file-server-password infected \
        --file-extraction all \
        --file-preservation quarantined \
        --file-scan-rule-update true \
        --filebeat-tcp-expose true \
        --logstash-expose true \
        --netbox false \
        --opensearch-expose true \
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
    if [[ "$(uname -m)" == "aarch64" ]]; then
        if ! docker images -a | grep ghcr.io/mmguero-dev/jekyll > /dev/null ; then
            info-message "Build jekyll for aarch64 first"
            cd ~ || exit
            git clone https://github.com/mmguero-dev/jekyll-serve.git
            cd jekyll-serve || exit
            docker build --tag ghcr.io/mmguero-dev/jekyll:latest .
        fi
    fi
    cd ~/Malcolm || exit
    sed -i -e "s/DOCKER_COMPOSE_COMMAND --progress=plain build/DOCKER_COMPOSE_COMMAND build --progress=plain /" scripts/build.sh
    if [[ -z ${MAXMIND_KEY} ]]; then
        # shellcheck disable=SC1091
        source "${HOME}/Malcolm/config/arkime-secret.env"
        MAXMIND_KEY="${MAXMIND_GEOIP_DB_LICENSE_KEY}"
        if [[ -z ${MAXMIND_KEY} ]]; then
            malcolm-maxmind
        fi
    fi
    COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 MAXMIND_GEOIP_DB_LICENSE_KEY="${MAXMIND_KEY}" ./scripts/build.sh
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


# Function to change settings for docker-compose
function malcolm-docker-compose() {
    info-message "Increase retries in docker-compose.yml"
    sed -i -e "s/retries: 3$/retries: 40/" ~/Malcolm/docker-compose.yml
    if ! dpkg -l | grep -v docker-compose-plugin | grep docker-compose > /dev/null ; then
        sudo apt install -yqq docker-compose > /dev/null 2>&1
    fi
    info-message "Done increasing retries in docker-compose.yml"
    touch "${CONFIG_DIR}/docker_compose_done"
}


# Function to add intel from Critical Path Security to Zeek
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


# Change nginx configuration - add wise
function nginx-configure(){
    info-message "Configure nginx."
    cd ~/Malcolm || exit
    sed -i -e "/  upstream upload/i \ \ upstream arkime-wise {\n    server arkime:8081;\n  }\n" nginx/nginx.conf
    sed -i -e "/  upstream upload/i \ \ upstream nfa {\n    server nfa:5001;\n  }\n" nginx/nginx.conf
    # shellcheck disable=SC2016
    sed -i -e '/    # Malcolm file upload/i \ \ \ \ # Arkime wise\n    location ~* \/wise\/(.*) {\n      proxy_pass http:\/\/arkime-wise\/\$1;\n      proxy_redirect off;\n      proxy_set_header Host wise.malcolm.local;\n    }\n' nginx/nginx.conf
    # shellcheck disable=SC2016
    sed -i -e '/    # Malcolm file upload/i \ \ \ \ # nfa\n    location ~* \/nfa\/(.*) {\n      proxy_pass http:\/\/nfa\/\$1;\n      proxy_redirect off;\n      proxy_set_header Host wise.malcolm.local;\n    }\n' nginx/nginx.conf
    touch "${CONFIG_DIR}/nginx_done"
}


# Function to change Arkime configuration
function malcolm-configure-arkime(){
    info-message "Configure Arkime"
    cd ~/Malcolm || exit
    sed -i -e "s/parseCookieValue=false/parseCookieValue=true/" arkime/etc/config.ini
    sed -i -e "s/parseDNSRecordAll=false/parseDNSRecordAll=true/" arkime/etc/config.ini
    sed -i -e "s/parseHTTPHeaderRequestAll=false/parseHTTPHeaderRequestAll=true/" arkime/etc/config.ini
    sed -i -e "s/parseHTTPHeaderResponseAll=false/parseHTTPHeaderResponseAll=true/" arkime/etc/config.ini
    sed -i -e "s/parseQSValue=false/parseQSValue=true/" arkime/etc/config.ini
    sed -i -e "s/parseSMTPHeaderAll=false/parseSMTPHeaderAll=true/" arkime/etc/config.ini
    sed -i -e "s/supportSha256=false/supportSha256=true/" arkime/etc/config.ini
    sed -i -e "s/maxReqBody=.*/maxReqBody=0/" arkime/etc/config.ini
    sed -i -e "s/spiDataMaxIndices=.*/spiDataMaxIndices=10000/" arkime/etc/config.ini
    sed -i -e "s_# implicit.*_includes=/opt/arkime/etc/config-local.ini_" arkime/etc/config.ini
    sed -i -e "s/--insecure/--insecure --webconfig/" arkime/scripts/wise_service.sh
    cp ~/malir/resources/config-local.ini arkime/etc
    touch "${CONFIG_DIR}/arkime_done"
}


function add-nfa(){
    info-message "Add nfa"
    cd ~/Malcolm || exit
    [[ -d nfa ]] || git clone https://github.com/reuteras/nfa.git
    cp ~/malir/resources/nfa-config.ini nfa/config.ini
    if ! grep "nfa:" docker-compose* > /dev/null 2>&1 ; then
        sed -i "/services:/r ${HOME}/malir/resources/nfa-docker-compose.yml" docker-compose.yml
        sed -i "/services:/r ${HOME}/malir/resources/nfa-docker-compose-standalone.yml" docker-compose-standalone.yml
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
    git clone https://github.com/idaholab/Malcolm.git
    cd Malcolm || exit
    git fetch --all --tags
    info-message "Using version $MALCOLM_VERSION of Malcolm."
    git checkout tags/"$MALCOLM_VERSION" 2>&1 | grep Note
fi

if [[ "$(uname -m)" == "aarch64" && ! -f "${CONFIG_DIR}/aarch64_done" ]]; then
    info-message "Fixes for aarch64"
    cd ~/Malcolm || exit
    sed -i -e "s/amd64/arm64/g" scripts/install.py
    SUPERSONIC_VERSION=$(grep "ENV SUPERCRONIC_VERSION" Dockerfiles/zeek.Dockerfile | grep -oE "[0-9.]+")
    SUPERCRONIC_URL=$(grep "ENV SUPERCRONIC_URL" Dockerfiles/zeek.Dockerfile | \
        grep -oE 'https[^"]+' | \
        sed -E "s/SUPERCRONIC_VERSION/$SUPERSONIC_VERSION/" | \
        sed -E "s/amd64/arm64/g" | \
        tr -d '$')
    SUPERSONIC_SHA1SUM=$(curl -L -s "${SUPERCRONIC_URL}" -o - | shasum | awk '{print $1}')
    for dockerfile in Dockerfiles/*; do
        sed -i -e "s/amd64/arm64/g" "${dockerfile}"
        sed -i -e "s#/tini /usr/bin/tini#/tini-arm64 /usr/bin/tini#g" "${dockerfile}"
        sed -i -e "s/ENV SUPERCRONIC_SHA1SUM .*/ENV SUPERCRONIC_SHA1SUM "'"'"${SUPERSONIC_SHA1SUM}"'"'"/" "${dockerfile}"
    done
    touch "${CONFIG_DIR}/aarch64_done"
fi

test -e "${CONFIG_DIR}/ubuntu_done" || update-ubuntu
test -e "${CONFIG_DIR}/configure_done" || malcolm-configure
test -e "${CONFIG_DIR}/maxmind_done" || malcolm-maxmind
test -e "${CONFIG_DIR}/docker_compose_done" || malcolm-docker-compose
test -e "${CONFIG_DIR}/zeek_intel_done" || malcolm-zeek-intel
test -e "${CONFIG_DIR}/arkime_done" || malcolm-configure-arkime
test -e "${CONFIG_DIR}/nginx_done" || nginx-configure
test -e "${CONFIG_DIR}/nfa_done" || add-nfa
test -e "${CONFIG_DIR}/build_done" || malcolm-build

info-message "Installation done."
info-message "Start Malcolm by changing to the ~/Malcolm directory and run ./scripts/start."
