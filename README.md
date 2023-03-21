# malir

My scripts to install [Malcolm][mal] for incident response (IR). The goal is not to have a lean version of Malcolm after installation, rather the goal is to have all bells and whistles in the included as well as adding some more and enable the maximal amount of indexing.

## Installation

This script is only tested on Ubuntu 22.04 LTS and I recommend running it in VM. The script will change default background during installation. Image is from [SANS][san]. There are also other changes that you might not want on your regular computer.

Start by cloning the repo and entering it. If you don't have git installed start with **sudo apt install -y git**.

    git clone https://github.com/reuteras/malir.git
    cd malir

Before the installation is finished you will have to logout one time (update group membership for Docker) and reboot the computer one time (updated settings). You have to rerun the **install.sh** script after logging out and rebooting the computer. The **install.sh** script will tell you when to logout and reboot. To start the process run the following command in the malir directory.

    ./install.sh

The Malcolm scripts are interactive so you can select settings. Usually I use the defaults and only change:

- Enable file extraction with Zeek? -> yes
- Select file extraction behavior -> all
- Select file preserveration behavior -> all
- Scan extracted files with ClamAV -> yes
- Scan extracted files with Yara -> yes
- Scan extracted PE files with Capa? -> yes

After the installation is finished you can optionally run the following command to install some additional tools. See the script for more information.

    ./tools.sh

Other scripts:

- clean.sh - Clean apt and run **docker system prune**
- download-test-pcaps.sh - Downloads some sample pcaps from [Malware-Traffic-Analysis.net][maw].
- update.sh - Updates Zeek feeds. Must restart Malcolm afterwards.
- zero.sh - Write zeros to free space. Don't do this if you have a large disk in the VM.

## Usage

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

The easiest solution is to just `cd ~/Malcolm` and then run `./scripts/start` which will build missing images.

Otherwise you can use this **very** ugly bash line to list missing images (the last **grep -v** will miss lines - only tested for my latest problem). You have to build them in the order they appear in *~/Malcolm/docker-compose.yml*.

```bash
for image in $(grep image: ~/Malcolm/docker-compose.yml | cut -f2 -d: | tr -d ' '| sort | uniq  | grep -vE "$(docker images -a | cut -f1 -d\  | grep '/' | sort | uniq | tr '\n' '|')NOMATCH"); do grep -m1 -B5 $image ~/Malcolm/docker-compose.yml ; done | grep -v ": [0-9A-Za-z.]" | grep -v "build:"  | tr -d " :"
```

When building is done do `touch ~/.config/manir/build_done` and run install.sh again.

### Netbox container fails

If netbox fails and your not using it you can remove the line with **jq** and the next line with **mv** and then try again.

## TODO

- [ ] Add support to tag TOR exit nodes.
- [ ] Try and see if [nfa][nfa] is useful.
- [ ] Add more right-click functionality to Arkime
- [ ] More plugins to Zeek?
- [ ] Look at the Malcolm [api][api] and the examples searching for *user-agent* and more.
- [ ] Read [Ingesting Third-Party Logs][itl] and [Forwarding Third-Party Logs to Malcolm][ftl]
- [x] Is it useful to have an [update][upd] script for this usecase? - Don't write an update function. Create instance for every incident. - Adding script to update rules added (Zeek).
- [ ] How to verify that Logstash is up?
- [ ] Read more about freq and how it is used in Malcolm.
- [ ] Add support for Rita.
- [ ] *cidr-map.txt* - should always be set
- [ ] Look at *malcolm_severity.yaml* and if I should tune the values for my usecases.
- [x] Do **git clone https://github.com/CriticalPathSecurity/Zeek-Intelligence-Feeds.git** in the directory zeek/intel. Read more at [Critical Path Security][cps] and in the Malcolm documentation for [Zeek Intelligence Framework][zif]
- [ ] STIX and [TAXII][sta] in Malcolm
- [ ] MISP [feeds][mis] in Malcolm
- [ ] Look at [alerting][ale] `event.dataset` set to `alerting`
- [x] Read the docs about [contributing][con].
- [x] Update Arkime conf





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
