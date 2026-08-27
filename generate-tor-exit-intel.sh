#!/bin/bash

set -Eeuo pipefail

readonly COLLECTOR_BASE_URL="https://collector.torproject.org/archive/exit-lists"
readonly MALCOLM_DIR="${MALCOLM_DIR:-${HOME}/Malcolm}"
readonly OUTPUT_DIR="${MALCOLM_DIR}/zeek/intel/Tor"
readonly METADATA_DIR="${HOME}/.config/malir/tor-exit-intel"

function usage() {
    echo "Usage: $0 YYYY-MM-DD" >&2
}

function error-exit() {
    echo "**** ERROR: $*" >&2
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
    exit 2
fi

readonly INTEL_DATE="$1"
[[ ${INTEL_DATE} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
    error-exit "Date must use the YYYY-MM-DD format."

NORMALIZED_DATE=$(date --date="${INTEL_DATE}" +%F 2>/dev/null) ||
    error-exit "Invalid date: ${INTEL_DATE}."
[[ ${NORMALIZED_DATE} == "${INTEL_DATE}" ]] ||
    error-exit "Invalid date: ${INTEL_DATE}."
[[ ${INTEL_DATE} < "$(date +%F)" || ${INTEL_DATE} == "$(date +%F)" ]] ||
    error-exit "Date cannot be in the future."

[[ -d ${MALCOLM_DIR}/zeek/intel ]] ||
    error-exit "Malcolm intelligence directory not found at ${MALCOLM_DIR}/zeek/intel."

readonly YEAR_MONTH="${INTEL_DATE:0:7}"
readonly DAY="${INTEL_DATE:8:2}"
readonly ARCHIVE_NAME="exit-list-${YEAR_MONTH}.tar.xz"
readonly ARCHIVE_URL="${COLLECTOR_BASE_URL}/${ARCHIVE_NAME}"
readonly OUTPUT_FILE="${OUTPUT_DIR}/tor-exit-nodes-${INTEL_DATE}.intel"
readonly METADATA_FILE="${METADATA_DIR}/tor-exit-nodes-${INTEL_DATE}.txt"

WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "${WORK_DIR}"' EXIT
readonly ARCHIVE_FILE="${WORK_DIR}/${ARCHIVE_NAME}"
readonly ADDRESS_FILE="${WORK_DIR}/addresses.txt"
readonly INTEL_FILE="${WORK_DIR}/tor-exit-nodes.intel"

echo "**** INFO: Downloading ${ARCHIVE_URL}"
curl --fail --location --silent --show-error "${ARCHIVE_URL}" --output "${ARCHIVE_FILE}" ||
    error-exit "Unable to download the Tor exit-list archive for ${YEAR_MONTH}."

mapfile -t SNAPSHOT_FILES < <(
    tar -tf "${ARCHIVE_FILE}" |
        grep -E "^exit-list-${YEAR_MONTH}/${DAY}/${INTEL_DATE}-[0-9]{2}-[0-9]{2}-[0-9]{2}$" |
        LC_ALL=C sort
)
readonly SNAPSHOT_COUNT=${#SNAPSHOT_FILES[@]}
(( SNAPSHOT_COUNT > 0 )) ||
    error-exit "The archive contains no exit-list snapshots for ${INTEL_DATE}."

tar -xOf "${ARCHIVE_FILE}" "${SNAPSHOT_FILES[@]}" |
    awk '
        function is_ipv4(value, octets, count, i) {
            count = split(value, octets, ".")
            if (count != 4) return 0
            for (i = 1; i <= 4; i++) {
                if (octets[i] !~ /^[0-9]+$/ || octets[i] < 0 || octets[i] > 255) return 0
            }
            return 1
        }
        $1 == "ExitAddress" && is_ipv4($2) { print $2 }
    ' |
    LC_ALL=C sort -u >"${ADDRESS_FILE}"

ADDRESS_COUNT=$(wc -l <"${ADDRESS_FILE}" | tr -d ' ')
readonly ADDRESS_COUNT
(( ADDRESS_COUNT > 0 )) ||
    error-exit "No valid Tor exit addresses were found for ${INTEL_DATE}."

{
    printf '#fields\tindicator\tindicator_type\tmeta.source\tmeta.desc\tmeta.url\n'
    while IFS= read -r address; do
        printf '%s\tIntel::ADDR\tTor Project CollecTor\tListed in Tor exit snapshots for %s\t%s\n' \
            "${address}" "${INTEL_DATE}" "${ARCHIVE_URL}"
    done <"${ADDRESS_FILE}"
} >"${INTEL_FILE}"

mkdir -p -- "${OUTPUT_DIR}" "${METADATA_DIR}"
install -m 0644 "${INTEL_FILE}" "${OUTPUT_FILE}"

ARCHIVE_SHA256=$(sha256sum "${ARCHIVE_FILE}" | awk '{print $1}')
{
    printf 'date=%s\n' "${INTEL_DATE}"
    printf 'source=%s\n' "${ARCHIVE_URL}"
    printf 'archive_sha256=%s\n' "${ARCHIVE_SHA256}"
    printf 'snapshots=%s\n' "${SNAPSHOT_COUNT}"
    printf 'unique_exit_addresses=%s\n' "${ADDRESS_COUNT}"
    printf 'output=%s\n' "${OUTPUT_FILE}"
} >"${METADATA_FILE}"
chmod 0644 "${METADATA_FILE}"

echo "**** INFO: Wrote ${ADDRESS_COUNT} unique Tor exit addresses from ${SNAPSHOT_COUNT} snapshots."
echo "**** INFO: Intelligence file: ${OUTPUT_FILE}"
echo "**** INFO: Provenance: ${METADATA_FILE}"
echo "**** INFO: Restart Malcolm before processing PCAPs if it is already running."
