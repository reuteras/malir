# malir

A collection of scripts to simplify the install of [Malcolm][mal] for incident response (IR). The goal of this project is to have an installation of Malcolm with most tools installed, not a small and minimal installation.

## Installation

Scripts are only tested on Ubuntu 22.04 LTS and Debian 12.1. The scripts should work on amd64 as well as on arm64 (Apple M1 and later).Its recommended running the script in a virtual machine.

Start by cloning the repository and entering it. If you don't have git installed start with **sudo apt install -y git**. It is recommended that you check out the repository in your home directory.

    cd
    git clone https://github.com/reuteras/malir.git
    cd malir

Before the installation is finished you will have to logout one time (update group membership for Docker) and reboot the computer one time (updated settings). You have to rerun the **install.sh** script after logging out and rebooting the computer. The **install.sh** script will tell you when to logout and reboot. To start the process run the following command in the malir directory.

    ./install.sh

After the installation is finished you can optionally run the following command to install some additional tools. See the script for more information.

    ./tools.sh

Other scripts:

- clean.sh - Clean apt and run **docker system prune**
- download-test-pcaps.sh - Downloads some sample pcaps from [Malware-Traffic-Analysis.net][maw].
- update.sh - Updates Zeek feeds. Must restart Malcolm afterwards.

## Usage

The script will set the username to _admin_ and the password will be _password_.

### Start

Start Malcolm:

    cd ~/Malcolm
    ./script/start

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

## TODO

- [ ] Add support to tag TOR exit nodes.
- [ ] Try and see if [nfa][nfa] is useful.
- [x] Add more right-click functionality to Arkime
- [ ] More plugins to Zeek?
- [ ] Look at the Malcolm [api][api] and the examples searching for *user-agent* and more.
- [ ] Read [Ingesting Third-Party Logs][itl] and [Forwarding Third-Party Logs to Malcolm][ftl]
- [ ] Read more about freq and how it is used in Malcolm.
- [ ] Add support for Rita.
- [ ] *cidr-map.txt* - should always be set
- [ ] Look at *malcolm_severity.yaml* and if I should tune the values for my usecases.
- [ ] STIX and [TAXII][sta] in Malcolm
- [ ] MISP [feeds][mis] in Malcolm
- [ ] Look at [alerting][ale] `event.dataset` set to `alerting`
- [ ] Look at _smtpIpHeaders_ in Arkime settings


  [ale]: https://github.com/cisagov/Malcolm#alerting
  [api]: https://github.com/cisagov/Malcolm#api
  [con]: https://github.com/cisagov/Malcolm/blob/main/docs/contributing/README.md
  [cps]: https://github.com/CriticalPathSecurity/Zeek-Intelligence-Feeds
  [ftl]: https://github.com/cisagov/Malcolm/blob/main/scripts/third-party-logs/README.md
  [itl]: https://github.com/cisagov/Malcolm#ingesting-third-party-logs
  [las]: https://127.0.0.1/sessions
  [lda]: https://127.0.0.1/dashboards
  [lef]: https://127.0.0.1/extracted-files/
  [lhn]: https://127.0.0.1/name-map-ui/
  [luf]: https://127.0.0.1:488/
  [lup]: https://127.0.0.1/upload
  [mal]: https://github.com/cisagov/Malcolm
  [maw]: https://www.malware-traffic-analysis.net/
  [mis]: https://github.com/cisagov/Malcolm#misp
  [nfa]: https://github.com/ansv46/nfa.git
  [san]: https://www.sans.org/blog/sans-zoom-backgrounds/
  [sta]: https://github.com/cisagov/Malcolm#stix-and-taxii
  [upd]: https://github.com/cisagov/Malcolm#UpgradePlan
  [zif]: https://github.com/cisagov/Malcolm#zeek-intelligence-framework
