#!/bin/bash

set -Eeuo pipefail

CONFIG_DIR="${HOME}/.config/malir"
PATH="${PATH}:/usr/libexec/docker/cli-plugins"
MALCOLM_VERSION="v26.08.0"
ALKEME_VERSION="v0.5.0"
ALKEME_SHA256="24fa01a8a2628a9a2ca52ac6bf354add65ed890c40d0c0e9f3581ffbea7dc7e6"
# Malcolm pins the ja4 zkg package (zeek/scripts/zeek_install_plugins.sh) to a commit
# that zkg's package-info step can no longer resolve: that step always does a
# --depth=1 clone, which only contains the tip of each branch, and FoxIO-LLC/ja4's
# main branch has since moved past Malcolm's pinned commit. Repin to a commit that
# was the tip of main when this was last checked; expect this to need updating again
# as ja4 gets new commits.
ZEEK_JA4_PLUGIN_COMMIT_BROKEN="40aa9321be95793cc361ba1edd6cf14f12707486"
ZEEK_JA4_PLUGIN_COMMIT="e02d9dca595cb8e7b042177881a381c4846a17a3"
MALCOLM_DIR="${HOME}/Malcolm"
MALIR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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

function require-supported-platform() {
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ ${ID:-} == "debian" && ${VERSION_ID:-} == "13" ]] ||
        error-exit-message "This installer supports Debian 13 only."
    [[ $(dpkg --print-architecture) == "arm64" ]] ||
        error-exit-message "This installer supports arm64 only."
}

function require-single-match() {
    local pattern="$1"
    local file="$2"
    local count
    count=$(grep -Ec -- "${pattern}" "${file}" || true)
    [[ ${count} -eq 1 ]] ||
        error-exit-message "Expected one match for '${pattern}' in ${file}, found ${count}."
}

function replace-once() {
    local pattern="$1"
    local replacement="$2"
    local expected="$3"
    local file="$4"

    if grep -Eq -- "${expected}" "${file}"; then
        return
    fi
    require-single-match "${pattern}" "${file}"
    sed -i -e "s|${pattern}|${replacement}|" "${file}"
    grep -Eq -- "${expected}" "${file}" ||
        error-exit-message "Failed to update ${file}."
}

function replace-all() {
    local pattern="$1"
    local replacement="$2"
    local expected="$3"
    local file="$4"

    if ! grep -Eq -- "${pattern}" "${file}"; then
        grep -Eq -- "${expected}" "${file}" ||
            error-exit-message "Neither the original nor expected value was found in ${file}."
        return
    fi
    sed -i -e "s|${pattern}|${replacement}|g" "${file}"
    ! grep -Eq -- "${pattern}" "${file}" ||
        error-exit-message "Failed to replace every match in ${file}."
    grep -Eq -- "${expected}" "${file}" ||
        error-exit-message "Expected value was not found after updating ${file}."
}

function docker-ready() {
    docker --version >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

function alkeme-ready() {
    [[ -x /usr/local/bin/alkeme ]] &&
        [[ $(/usr/local/bin/alkeme --version 2>/dev/null) == "alkeme ${ALKEME_VERSION#v}" ]]
}

function os-ready() {
    local package
    for package in apache2-utils ca-certificates curl moreutils openssl python3-ruamel.yaml python3-dotenv python3-dialog dialog; do
        dpkg-query -W -f='${db:Status-Status}\n' "${package}" 2>/dev/null | grep -Fqx "installed"
    done
}

function maxmind-ready() {
    local file="${MALCOLM_DIR}/config/arkime-secret.env"
    [[ -f ${file} ]] &&
        grep -Eq '^MAXMIND_GEOIP_DB_ACCOUNT_ID=.+$' "${file}" &&
        ! grep -Eq '^MAXMIND_GEOIP_DB_ACCOUNT_ID=0$' "${file}" &&
        grep -Eq '^MAXMIND_GEOIP_DB_LICENSE_KEY=.+$' "${file}" &&
        ! grep -Eq '^MAXMIND_GEOIP_DB_LICENSE_KEY=0$' "${file}"
}

function configure-ready() {
    local settings_file
    settings_file=$(mktemp --suffix=.json)
    if ! (cd "${MALCOLM_DIR}" && ./scripts/configure --dry-run --non-interactive --export-malcolm-config-file "${settings_file}" >/dev/null); then
        rm -f "${settings_file}"
        return 1
    fi
    if jq -e '
        .configuration.dashboardsDarkMode == true and
        .configuration.reverseDns == true and
        .configuration.fileCarveHttpServer == true and
        .configuration.fileCarveMode == "all" and
        .configuration.filePreserveMode == "all" and
        .configuration.malcolmIcs == false and
        .configuration.zeekICSBestGuess == false
    ' "${settings_file}" >/dev/null; then
        rm -f "${settings_file}"
        return 0
    fi
    rm -f "${settings_file}"
    return 1
}

function zeek-intel-ready() {
    local file="${MALCOLM_DIR}/zeek/intel/Zeek-Intelligence-Feeds/main.zeek"
    [[ -f ${file} ]] &&
        ! grep -Fq '/usr/local/zeek/share/zeek/site/Zeek-Intelligence-Feeds' "${file}" &&
        grep -Fq '/opt/zeek/share/zeek/site/intel/Zeek-Intelligence-Feeds' "${file}"
}

function zeek-ja4-pin-ready() {
    local file="${MALCOLM_DIR}/zeek/scripts/zeek_install_plugins.sh"
    [[ -f ${file} ]] &&
        grep -Fq "FoxIO-LLC/ja4|${ZEEK_JA4_PLUGIN_COMMIT}" "${file}" &&
        ! grep -Fq "${ZEEK_JA4_PLUGIN_COMMIT_BROKEN}" "${file}"
}

function arkime-ready() {
    [[ -f ${MALCOLM_DIR}/arkime/etc/config-local.ini ]] &&
        cmp -s "${MALIR_DIR}/resources/config-local.ini" "${MALCOLM_DIR}/arkime/etc/config-local.ini" &&
        grep -Fqx 'includes=/opt/arkime/etc/config-local.ini' "${MALCOLM_DIR}/arkime/etc/config.ini"
}

function nginx-ready() {
    # shellcheck disable=SC2016
    grep -Fq 'upstream nfa {' "${MALCOLM_DIR}/nginx/nginx.conf" &&
        grep -Fq 'proxy_pass http://nfa/$1;' "${MALCOLM_DIR}/nginx/nginx.conf"
}

function nfa-ready() {
    [[ -f ${MALCOLM_DIR}/nfa/config.ini ]] &&
        cmp -s "${MALIR_DIR}/resources/nfa-config.ini" "${MALCOLM_DIR}/nfa/config.ini" &&
        (cd "${MALCOLM_DIR}" && docker compose -f docker-compose.yml config --quiet &&
            docker compose -f docker-compose.yml config --services | grep -Fqx nfa) &&
        (cd "${MALCOLM_DIR}" && docker compose -f docker-compose-dev.yml config --quiet &&
            docker compose -f docker-compose-dev.yml config --services | grep -Fqx nfa)
}

function add-nfa-compose-service() {
    local compose_file="$1"
    local service_file="$2"
    if docker compose -f "${compose_file}" config --services 2>/dev/null | grep -Fqx nfa; then
        return
    fi
    require-single-match '^services:$' "${compose_file}"
    sed -i "/services:/r ${service_file}" "${compose_file}"
}

function build-ready() {
    local image
    local found=false
    while IFS= read -r image; do
        [[ -n ${image} ]] || continue
        found=true
        docker image inspect "${image}" >/dev/null 2>&1 || return 1
    done < <(cd "${MALCOLM_DIR}" && docker compose -f docker-compose-dev.yml config --images)
    [[ ${found} == true ]]
}

function stage-complete() {
    local marker="$1"
    local validator="$2"
    [[ -e ${CONFIG_DIR}/${marker} ]] && "${validator}"
}

# Function to update Ubuntu
function update-os() {
    info-message "Running apt update."
    # shellcheck disable=SC2024
    sudo apt-get update
    info-message "Running apt dist-upgrade."
    local attempt
    for attempt in {1..6}; do
        if sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade; then
            break
        fi
        [[ ${attempt} -lt 6 ]] || error-exit-message "APT dist-upgrade failed after 6 attempts."
        info-message "APT failed or is busy. Retrying in 10 seconds (${attempt}/6)."
        sleep 10
    done
    info-message "Running apt install to install needed packages."
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apache2-utils ca-certificates curl moreutils openssl python3-ruamel.yaml python3-dotenv python3-dialog dialog
    if command -v snap >/dev/null; then
        info-message "Update snap."
        sudo snap refresh
    fi
    os-ready || error-exit-message "Required operating-system packages are missing after installation."
    touch "${CONFIG_DIR}/os_done"
}

# Install Docker
function install-docker() {
    if docker-ready; then
        touch "${CONFIG_DIR}/docker_done"
        return
    fi
    sudo install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc >/dev/null 2>&1
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # shellcheck disable=SC1091
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    info-message "Install Docker."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    docker-ready || error-exit-message "Docker or the Docker Compose plugin is not available after installation."
    touch "${CONFIG_DIR}/docker_done"
}

# Install Alkeme, the Arkime terminal user interface
function install-alkeme() {
    local asset="alkeme-linux-arm64"
    local download_url="https://github.com/arkime/alkeme/releases/download/${ALKEME_VERSION}/${asset}"
    local temp_dir
    local temp_file

    if alkeme-ready; then
        touch "${CONFIG_DIR}/alkeme_done"
        return
    fi

    info-message "Install Alkeme ${ALKEME_VERSION}."
    temp_dir=$(mktemp -d)
    temp_file="${temp_dir}/${asset}"
    if ! curl --fail --location --silent --show-error "${download_url}" --output "${temp_file}"; then
        rm -rf -- "${temp_dir}"
        error-exit-message "Failed to download Alkeme ${ALKEME_VERSION}."
    fi
    if ! echo "${ALKEME_SHA256}  ${temp_file}" | sha256sum --check --status; then
        rm -rf -- "${temp_dir}"
        error-exit-message "Alkeme ${ALKEME_VERSION} checksum verification failed."
    fi
    sudo install -m 0755 "${temp_file}" /usr/local/bin/alkeme
    rm -rf -- "${temp_dir}"
    alkeme-ready || error-exit-message "Alkeme installation validation failed."
    touch "${CONFIG_DIR}/alkeme_done"
}

# Function to configure Malcolm
function malcolm-configure() {
    info-message "Starting automatic configuration of Malcolm"
    cd "${MALCOLM_DIR}" || exit

    # From https://malcolm.fyi/docs/malcolm-config.html#CommandLineConfig
    # export the current configuration to a JSON file without modifying anything in ./config/
    SETTINGS_FILE="$(mktemp --suffix=.json)"
    ./scripts/configure --dry-run --non-interactive --export-malcolm-config-file "${SETTINGS_FILE}"

    # use JQ To set whatever options in the exported JSON configuration file you wish to change
    JQ_FILE="$(mktemp --suffix=.jq)"
    tee "${JQ_FILE}" >/dev/null <<EOF
        .configuration.dashboardsDarkMode = true
        | .configuration.reverseDns = true
        | .configuration.fileCarveHttpServer = true
        | .configuration.fileCarveMode = "all"
        | .configuration.filePreserveMode = "all"
        | .configuration.malcolmIcs = false
        | .configuration.zeekICSBestGuess = false
EOF
    jq -f "${JQ_FILE}" "${SETTINGS_FILE}" | sponge "${SETTINGS_FILE}"

    # import the modified configuration
    ./scripts/configure --non-interactive --import-malcolm-config-file "${SETTINGS_FILE}"

    # clean up
    rm -f "${SETTINGS_FILE}" "${JQ_FILE}"
    # End from https://malcolm.fyi/docs/malcolm-config.html#CommandLineConfig

    sudo python3 scripts/install.py --non-interactive
    # shellcheck disable=SC2016
    python3 scripts/auth_setup \
        --auth \
        --auth-noninteractive \
        --auth-method basic \
        --auth-admin-username admin \
        --auth-admin-password-htpasswd '$2y$05$N37mG4dLlQAHccESse3mL.6NGqLOqo/Vf5DpKoEmEeAL5mk8i15Ja' \
        --auth-admin-password-openssl '$1$RD8JxZlf$2aHwWP71GY3kKjMNfjIKu0' \
        --auth-arkime-password ArkimePassword123 \
        --auth-generate-webcerts \
        --auth-generate-fwcerts \
        --auth-generate-netbox-passwords \
        --auth-generate-valkey-password \
        --auth-generate-postgres-password \
        --auth-generate-opensearch-internal-creds
    configure-ready || error-exit-message "Malcolm configuration validation failed."
    info-message "Configuration of Malcolm done."
    touch "${CONFIG_DIR}/configure_done"
    info-message "Reboot to update settings. Then run the script install.sh again."
    exit
}

# Function to build Malcolm containers
function malcolm-build() {
    info-message "Starting build process for docker containers."
    info-message "This will take some time..."
    sudo sed -i -e "s/nameserver .*/nameserver 8.8.8.8/" /etc/resolv.conf
    cd "${MALCOLM_DIR}" || exit
    MAXMIND_ID="${MAXMIND_ID:-${MAXMIND_GEOIP_DB_ACCOUNT_ID:-}}"
    MAXMIND_KEY="${MAXMIND_KEY:-${MAXMIND_GEOIP_DB_LICENSE_KEY:-}}"
    if [[ -z ${MAXMIND_ID} || -z ${MAXMIND_KEY} ]]; then
        # shellcheck disable=SC1091
        source "${HOME}/Malcolm/config/arkime-secret.env"
        MAXMIND_ID="${MAXMIND_GEOIP_DB_ACCOUNT_ID}"
        MAXMIND_KEY="${MAXMIND_GEOIP_DB_LICENSE_KEY}"
        if [[ -z ${MAXMIND_ID} || -z ${MAXMIND_KEY} ]]; then
            malcolm-maxmind
            MAXMIND_ID="${MAXMIND_ACCOUNT}"
        fi
    fi
    replace-once '200000000' '100000000' '100000000' scripts/build.sh
    echo "N" | MAXMIND_GEOIP_DB_ACCOUNT_ID="${MAXMIND_ID}" MAXMIND_GEOIP_DB_LICENSE_KEY="${MAXMIND_KEY}" ZEEK_DEB_ALTERNATE_DOWNLOAD_URL=https://malcolm.fyi/zeek ./scripts/build.sh ./docker-compose-dev.yml
    info-message "Build done."
    read -rp "Verify build status above. If it failed type 'exit' (otherwise hit enter): " dummy
    if [[ ${dummy} == "exit" ]]; then
        exit
    fi
    build-ready || error-exit-message "One or more configured container images are missing after the build."
    touch "${CONFIG_DIR}/build_done"
}

# Function to set MaxMind GeoIP license key for Arkime
function malcolm-maxmind() {
    info-message "The build process needs your Maxmind API Key (free)"
    info-message "Get it from https://www.maxmind.com/"
    echo ""
    cd "${MALCOLM_DIR}" || exit
    MAXMIND_ACCOUNT=""
    MAXMIND_KEY=""
    while [[ -z "${MAXMIND_ACCOUNT}" ]]; do
        read -rp "Maxmind GeoIP account ID: " MAXMIND_ACCOUNT
    done
    while [[ -z "${MAXMIND_KEY}" ]]; do
        read -rp "Maxmind GeoIP license key (will echo key): " MAXMIND_KEY
    done
    export MAXMIND_ACCOUNT MAXMIND_KEY
    echo ""
    sed -i -e "s/MAXMIND_GEOIP_DB_ACCOUNT_ID=0/MAXMIND_GEOIP_DB_ACCOUNT_ID=$MAXMIND_ACCOUNT/" config/arkime-secret.env
    sed -i -e "s/MAXMIND_GEOIP_DB_LICENSE_KEY=0/MAXMIND_GEOIP_DB_LICENSE_KEY=$MAXMIND_KEY/" config/arkime-secret.env
    if grep "MAXMIND_GEOIP_DB_ACCOUNT_ID=0" config/arkime-secret.env >/dev/null 2>&1; then
        error-exit-message "Maxmind GeoIP License key not updated, exiting."
    fi
    if grep "MAXMIND_GEOIP_DB_LICENSE_KEY=0" config/arkime-secret.env >/dev/null 2>&1; then
        error-exit-message "Maxmind GeoIP License key not updated, exiting."
    fi
    maxmind-ready || error-exit-message "MaxMind configuration validation failed."
    touch "${CONFIG_DIR}/maxmind_done"
}

# Function to add intel from Critical Path Security to Zeek
function malcolm-zeek-intel() {
    info-message "Clone Zeek intel from Critical Path Security"
    if zeek-intel-ready; then
        touch "${CONFIG_DIR}/zeek_intel_done"
        return
    fi
    CDIR="$(pwd)"
    cd "${MALCOLM_DIR}/zeek/intel" || exit
    git clone https://github.com/CriticalPathSecurity/Zeek-Intelligence-Feeds.git >/dev/null 2>&1
    cd "${MALCOLM_DIR}" || exit
    replace-all '/usr/local/zeek/share/zeek/site/Zeek-Intelligence-Feeds' '/opt/zeek/share/zeek/site/intel/Zeek-Intelligence-Feeds' '/opt/zeek/share/zeek/site/intel/Zeek-Intelligence-Feeds' zeek/intel/Zeek-Intelligence-Feeds/main.zeek
    cd "${CDIR}" || exit
    zeek-intel-ready || error-exit-message "Zeek Intelligence Feeds installation validation failed."
    touch "${CONFIG_DIR}/zeek_intel_done"
}

# Function to repin the ja4 Zeek plugin to a commit zkg can actually resolve
function malcolm-patch-zeek-ja4() {
    info-message "Repin ja4 Zeek plugin to a resolvable commit"
    cd "${MALCOLM_DIR}" || exit
    replace-once "${ZEEK_JA4_PLUGIN_COMMIT_BROKEN}" "${ZEEK_JA4_PLUGIN_COMMIT}" "${ZEEK_JA4_PLUGIN_COMMIT}" zeek/scripts/zeek_install_plugins.sh
    zeek-ja4-pin-ready || error-exit-message "Failed to repin the ja4 Zeek plugin commit."
    touch "${CONFIG_DIR}/zeek_ja4_pin_done"
}

# Change nginx configuration - add nfa
function nginx-configure() {
    info-message "Configure nginx."
    cd "${MALCOLM_DIR}" || exit
    if nginx-ready; then
        touch "${CONFIG_DIR}/nginx_done"
        return
    fi
    require-single-match '^  upstream upload' nginx/nginx.conf
    require-single-match '^    # Malcolm file upload' nginx/nginx.conf
    sed -i -e "/  upstream upload/i \ \ upstream nfa {\n    server nfa:5001;\n  }\n" nginx/nginx.conf
    # shellcheck disable=SC2016
    sed -i -e '/    # Malcolm file upload/i \ \ \ \ # nfa\n    location ~* \/nfa\/(.*) {\n      proxy_pass http:\/\/nfa\/\$1;\n      proxy_redirect off;\n      proxy_set_header Host nfa.malcolm.local;\n    }\n' nginx/nginx.conf
    nginx-ready || error-exit-message "Failed to add the NFA nginx configuration."
    touch "${CONFIG_DIR}/nginx_done"
}

# Function to change Arkime configuration
function malcolm-configure-arkime() {
    info-message "Configure Arkime"
    cd "${MALCOLM_DIR}" || exit
    if ! grep -Fqx 'includes=/opt/arkime/etc/config-local.ini' arkime/etc/config.ini; then
        require-single-match '^\[default\]$' arkime/etc/config.ini
        sed -i -e '/^\[default\]$/a\
includes=/opt/arkime/etc/config-local.ini' arkime/etc/config.ini
    fi
    cp "${MALIR_DIR}/resources/config-local.ini" arkime/etc
    arkime-ready || error-exit-message "Failed to configure Arkime."
    touch "${CONFIG_DIR}/arkime_done"
}

function add-nfa() {
    info-message "Add nfa"
    cd "${MALCOLM_DIR}" || exit
    [[ -d nfa ]] || git clone https://github.com/reuteras/nfa.git >/dev/null
    cp "${MALIR_DIR}/resources/nfa-config.ini" nfa/config.ini
    add-nfa-compose-service docker-compose.yml "${MALIR_DIR}/resources/nfa-docker-compose.yml"
    add-nfa-compose-service docker-compose-dev.yml "${MALIR_DIR}/resources/nfa-docker-compose-dev.yml"
    nfa-ready || error-exit-message "NFA configuration or a Docker Compose file is invalid."
    touch "${CONFIG_DIR}/nfa_done"
}

# End of functions

# Create directory for status of installation and setup
info-message "Start installation of Malcolm and extra tools."
test -d "${CONFIG_DIR}" || mkdir -p "${CONFIG_DIR}"
require-supported-platform

# Check for membership in group docker
if ! grep "docker:" /etc/group | grep -E "(,|:)${USER}" >/dev/null; then
    info-message "Add current user to group docker."
    grep docker: /etc/group >/dev/null 2>&1 || sudo groupadd docker
    sudo usermod -aG docker "$USER" || exit
    info-message "Logout and back in again to update group memberships."
    exit
fi

# Checkout Malcolm in home dir
cd "${HOME}" || exit
if ! test -d "${MALCOLM_DIR}"; then
    git clone https://github.com/idaholab/Malcolm.git >/dev/null
    cd "${MALCOLM_DIR}" || exit
    git fetch --all --tags
    info-message "Using version $MALCOLM_VERSION of Malcolm."
    git checkout tags/"$MALCOLM_VERSION" 2>&1 | grep Note
else
    [[ -d ${MALCOLM_DIR}/.git ]] || error-exit-message "${MALCOLM_DIR} exists but is not a Git checkout."
    cd "${MALCOLM_DIR}" || exit
    MALCOLM_REMOTE=$(git remote get-url origin 2>/dev/null || true)
    [[ ${MALCOLM_REMOTE} == "https://github.com/idaholab/Malcolm.git" ||
        ${MALCOLM_REMOTE} == "git@github.com:idaholab/Malcolm.git" ]] ||
        error-exit-message "Existing Malcolm checkout has an unexpected origin: ${MALCOLM_REMOTE:-none}."
    EXPECTED_COMMIT=$(git rev-list -n 1 "${MALCOLM_VERSION}" 2>/dev/null || true)
    [[ -n ${EXPECTED_COMMIT} ]] || error-exit-message "Tag ${MALCOLM_VERSION} is not available in the existing Malcolm checkout."
    [[ $(git rev-parse HEAD) == "${EXPECTED_COMMIT}" ]] ||
        error-exit-message "Existing Malcolm checkout does not match ${MALCOLM_VERSION}."
fi

stage-complete os_done os-ready || update-os
stage-complete alkeme_done alkeme-ready || install-alkeme
stage-complete docker_done docker-ready || install-docker
stage-complete configure_done configure-ready || malcolm-configure
stage-complete maxmind_done maxmind-ready || malcolm-maxmind
stage-complete zeek_intel_done zeek-intel-ready || malcolm-zeek-intel
stage-complete arkime_done arkime-ready || malcolm-configure-arkime
stage-complete nginx_done nginx-ready || nginx-configure
stage-complete nfa_done nfa-ready || add-nfa
stage-complete zeek_ja4_pin_done zeek-ja4-pin-ready || malcolm-patch-zeek-ja4
stage-complete build_done build-ready || malcolm-build

info-message "Installation done."
info-message "Start Malcolm by changing to the ~/Malcolm directory and run ./scripts/start."
