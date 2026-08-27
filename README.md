# malir

A collection of scripts to simplify the install of [Malcolm][mal] for incident response (IR). The goal of this project is to have an installation of Malcolm with most tools installed, not a small and minimal installation.

## Installation

Scripts are only tested on Debian 13 running on arm64 (Apple M1 and later). It's recommended running the script in a virtual machine.

Start by cloning the repository and entering it. If you don't have git installed start with **sudo apt install -y git**. The script assumes that the repo is checked out in your home directory.

    cd
    git clone https://github.com/reuteras/malir.git
    cd malir

Before the installation is finished you will have to reboot the computer one time (updated settings and group memberships). You have to rerun the **install.sh** script after logging out and rebooting the computer. The **install.sh** script will tell you when to logout and reboot. To start the process run the following command in the malir directory.

    ./install.sh

After the installation is finished you can optionally run the following command to install some additional tools. See the script for more information.

    ./tools.sh

Other scripts:

- clean.sh - Clean unused apt packages and the apt package cache.
- download-test-pcaps.sh - Downloads some sample pcaps from [Malware-Traffic-Analysis.net][maw].
- generate-tor-exit-intel.sh - Generates a date-specific Zeek intelligence file
  containing Tor exit nodes.
- update.sh - Updates Zeek feeds. Must restart Malcolm afterwards.

### Tor exit-node intelligence

After Malcolm has been installed, generate Tor exit-node intelligence for the
date represented by the investigation PCAP:

    ./generate-tor-exit-intel.sh YYYY-MM-DD

The script downloads the official monthly Tor Project CollecTor archive and
combines every exit-list snapshot for that day. It writes the deduplicated Zeek
intelligence file to `~/Malcolm/zeek/intel/Tor/` and records the source archive,
SHA-256 digest and item counts under `~/.config/malir/tor-exit-intel/`.

This script does not require Malcolm's containers to be rebuilt. Run it after
installation and before starting Malcolm or uploading the PCAP. If Malcolm is
already running, restart it before processing the PCAP so Zeek regenerates its
intelligence loader.

## Usage

The script will set the username to _admin_ and the password will be _password_.

### Start

Start Malcolm:

    cd ~/Malcolm
    ./scripts/start

To check when Logstash is up and running you can run the following command in a separate terminal.

    cd ~/Malcolm; clear; ./scripts/logs | grep "Pipelines running"

Some useful Malcolm links on 127.0.0.1:

- [Capture File and Log Archive Upload][lup]
- [Arkime sessions][las]
- [Dashboards][lda]
- [Extracted files][lef]
- [User admin][luf]
- [Host and Network Segment Name Mapping][lhn]

To upload files via command line connect to **sftp://USERNAME@localhost:8022/files/**.

## Solutions

### Docker build failures

The easiest solution is to just to rerun **install.sh** and chose _N_ when asked about building.

## Changes to files in Malcolm

Containers are built with `docker-compose-dev.yml` as the argument to `~/Malcolm/scripts/build.sh`. The following scripts are run that can change files in Malcolm:

- ~/Malcolm/scripts/install.py
- ~/Malcolm/scripts/control.py

Changed files:

- ~/Malcolm/config/arkime-secret.env - Add password for MaxMind
- ~/Malcolm/zeek/intel/Zeek-Intelligence-Feeds/main.zeek - Add feeds from Critical Path Security
- ~/Malcolm/nginx/nginx.conf - Add `nfa` to the proxy
- ~/Malcolm/arkime/etc/config.ini - Modify settings for Arkime
- ~/Malcolm/arkime/etc/config-local.ini - Add this file

## Backlog and implementation options

The options below are scoped to improving the Malcolm installation inside an
investigation VM. Case management, VM creation and evidence handling are out of
scope for malir.

### Threat intelligence

- [x] Tag Tor exit nodes using `generate-tor-exit-intel.sh`.
  - The script uses the union of all official Tor Project CollecTor snapshots for
    the specified day and records the archive digest for reproducibility.
  - An alternative would be to expose the list through MISP or TAXII, but that
    introduces another service or account and is excessive for a standalone VM.
- [ ] Configure [STIX and TAXII][sta].
  - Malcolm already supports static STIX files and TAXII subscriptions. Start
    with a static, versioned STIX file in `~/Malcolm/zeek/intel/STIX/`.
  - Add an optional malir resource only if the same public TAXII feed is useful
    across most investigations. Keep credentials and case-specific endpoints out
    of this repository.
- [ ] Configure [MISP feeds][mis].
  - Malcolm already supports static MISP files and MISP feed subscriptions. A
    static export is the most reproducible option for an investigation VM.
  - Provide a documented template rather than a default live feed. MISP URLs,
    API keys and TLS settings are environment-specific.

### Analysis and enrichment

- [ ] Evaluate additional [Zeek scripts and plugins][crp].
  - First inventory the large set already built into Malcolm and identify a
    concrete missing protocol or detection. Do not add plugins speculatively.
  - For a small Zeek script, install it as a local script loaded by Malcolm. For
    a compiled plugin, pin its source commit and extend the Zeek image build.
  - Add a PCAP fixture and assert the expected Zeek log or notice before making
    any plugin part of the default installation.
- [x] Enable frequency scoring.
  - Malcolm's `freq` integration scores entropy in DNS names and TLS server
    names. The v26.08.0 installer enables it by default.
  - Future work should tune `FREQ_SEVERITY_THRESHOLD` using representative PCAPs
    rather than modifying the `freq` container. Lower values flag fewer,
    higher-entropy names; higher values flag more names.
- [ ] Evaluate [RITA][rita].
  - **Preferred experiment:** run RITA separately against the Zeek logs produced
    from a test PCAP and compare its beaconing findings with Malcolm dashboards.
  - **Possible integration:** use the official [RITA container][rita-container],
    which is published for `linux/arm64`, as an optional Compose service. Feed it
    Malcolm's Zeek logs and ingest a small, stable JSON or CSV export into
    Malcolm as third-party logs if that adds useful pivots.
  - RITA's documented host installer matrix lists `amd64`, but that does not
    prevent a container-based integration on malir's Debian ARM64 target.
  - Do not add RITA to the default build until the workflow has useful output,
    acceptable resource usage on ARM64 and an automated smoke test. Its database
    and transitive runtime dependencies materially increase the installation.
- [ ] Decide whether to customize [event severity scoring][sev].
  - Keep Malcolm's `logstash/maps/malcolm_severity.yaml` defaults initially and
    evaluate false positives using representative investigation PCAPs.
  - If tuning is justified, store a complete version-specific map under
    `resources/`, copy it during installation and validate every score is from
    `0` through `100`. A score of `0` disables a category.
  - Prefer tuning `FREQ_SEVERITY_THRESHOLD`,
    `TOTAL_MEGABYTES_SEVERITY_THRESHOLD` and `SENSITIVE_COUNTRY_CODES` before
    maintaining a full map fork.
- [ ] Review Arkime `smtpIpHeaders`.
  - Upstream already extracts `X-Originating-IP` and
    `X-Barracuda-Apparent-Source-IP` in v26.08.0.
  - Add headers only when a PCAP corpus demonstrates a missing mail-gateway
    header. Put the complete override in `resources/config-local.ini` and retain
    the upstream defaults because an override replaces the list.
- [x] Retire the `cidr-map.txt` task.
  - Malcolm v26.08.0 no longer contains that file. Use Malcolm's local NetBox
    inventory and enrichment when subnet and asset context is available, or add
    it manually inside the VM for a particular investigation.

### Querying and alerting

- [ ] Add small [Malcolm API][api] query examples.
  - Start with a dependency-free shell script using `curl` and `jq` against the
    field-aggregation API. Useful examples include HTTP user agents, DNS queries,
    TLS server names, JA4 fingerprints and severity tags.
  - Accept the uploaded-PCAP tag and time range as arguments so queries do not
    mix results from unrelated uploads.
  - Keep examples read-only. Automated report generation should be a separate
    decision after the queries prove useful interactively.
- [ ] Evaluate [alerting][ale].
  - Malcolm already provides a disabled loopback example that reindexes alerts
    with `event.dataset: alerting`.
  - For investigation VMs, create a small set of disabled monitor templates for
    high-severity events or specific indicators. Let the analyst enable them when
    useful; do not run continuous production-style notifications by default.

### Additional input formats

- [ ] Decide whether [third-party logs][ftl] belong in malir.
  - PCAP analysis needs no external forwarder. Malcolm can already upload Zeek
    logs and Windows event logs in supported archives.
  - Add configuration only if a repeatable investigation requires correlating a
    specific log format with PCAP results. Prefer uploaded files over opening a
    network listener in the VM.

### Completed experiments

- [x] Add [NFA][nfa] and expose it through Malcolm's internal nginx proxy.
- [x] Add Arkime right-click actions for NFA and external lookup sites.

  [ale]: https://malcolm.fyi/docs/alerting.html
  [api]: https://malcolm.fyi/docs/api.html
  [crp]: https://malcolm.fyi/docs/custom-rules.html
  [ftl]: https://malcolm.fyi/docs/third-party-logs.html
  [las]: https://127.0.0.1/sessions
  [lda]: https://127.0.0.1/dashboards
  [lef]: https://127.0.0.1/extracted-files/
  [lhn]: https://127.0.0.1/name-map-ui/
  [luf]: https://127.0.0.1:488/
  [lup]: https://127.0.0.1/upload
  [mal]: https://github.com/idaholab/Malcolm
  [maw]: https://www.malware-traffic-analysis.net/
  [mis]: https://malcolm.fyi/docs/zeek-intel.html#misp
  [nfa]: https://github.com/ansv46/nfa.git
  [rita]: https://github.com/activecm/rita
  [rita-container]: https://github.com/activecm/rita/pkgs/container/rita
  [sev]: https://malcolm.fyi/docs/severity.html
  [sta]: https://malcolm.fyi/docs/zeek-intel.html#stix-and-taxii
