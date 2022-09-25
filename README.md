# malir

My scripts to install [Malcolm][mal] for incident response (IR).

The plan is to start with Malcom and add more functions and tune the installation to make Malcolm even more useful for investigations related to IR and cases where you have pcap-files to investigate.

## Installation

This script is only tested on Ubuntu 22.04 LTS and I recommend running it in VM. The script will change default background during installation. Image is from [SANS][san].

Start by cloning the repo and entering it. If you don't have git installed start with **sudo apt install -y git**.

    git clone https://github.com/reuteras/malir.git
    cd malir

Before the installation is finished you will have to logout one time (update group membership for Docker) and reboot the computer one time (updated settings). You have to rerun the **install.sh** script after logging out and rebooting the computer. The **install.sh** script will tell you when to logout and reboot. To start the process run the following command in the manin

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
- zero.sh - Write zeros to free space. Don't do this if you have a large disk in the VM.

## Usage

Some useful Malcolm links on 127.0.0.1:

- [Capture File and Log Archive Upload][lup]
- [Arkime sessions][las]
- [Dashboards][lda]
- [Extracted files][lef]
- [User admin][luf]
- [Host and Network Segment Name Mapping][lhn]


To upload files via command line connect to **sftp://USERNAME@localhost:8022/files/**.

## TODO

- [ ] Add support to tag TOR exit nodes.
- [ ] Try and see if [nfa][nfa] is useful.
- [ ] Add more right-click functionality to Arkime
- [ ] More plugins to Zeek?
- [ ] Zeek [Intelligence Framework][zif] in Malcolm?
- [ ] Look at the Malcolm [api][api].
- [ ] Read [Ingesting Third-Party Logs][itl] and [Forwarding Third-Party Logs to Malcolm][ftl]
- [x] Is it useful to have an [update][upd] script for this usecase? - Don't write an update function. Create instance for every incident.
- [ ] How verify that Logstash is up?
- [ ] Read up about freq
- [ ] Add support for Rita
- [ ] *cidr-map.txt* - should always be set
- [ ] Look at *malcolm_severity.yaml*
- [ ] Do **git clone https://github.com/CriticalPathSecurity/Zeek-Intelligence-Feeds.git** in the directory zeek/intel. Read more on https://github.com/CriticalPathSecurity/Zeek-Intelligence-Feeds and https://github.com/cisagov/Malcolm#zeek-intelligence-framework
- [ ] STIX and TAXII - https://github.com/cisagov/Malcolm#stix-and-taxii
- [ ] MISP - https://github.com/cisagov/Malcolm#misp
- [ ] `event.dataset` set to `alerting` - https://github.com/cisagov/Malcolm#alerting
- [ ] API - https://github.com/cisagov/Malcolm#api 
- [ ] user-agent and others from examples
- [ ] READ: https://github.com/cisagov/Malcolm/blob/main/docs/contributing/README.md

```
parseCookieValue=true
parseQSValue=true
parseSMB=true
parseDNSRecordAll=true
parseSMTP=true
parseSMTPHeaderAll=true
parseHTTPHeaderRequestAll=true
parseHTTPHeaderResponseAll=true
```

Läs alla pcap-filer oavsett om de inte innehåller hela paket:

    readTruncatedPackets=true

Räkna även ut sha256

    supportSha256=true


    [git]: https://github.com/cisagov/Malcolm
    [mal]: https://malcolm.fyi/

Lägg till sektioner och utöka de framöver:

```
[headers-http-request]
referer=type:string;count:true;unique:true
```

```
[headers-http-response]
location=type:string
server=type:string
```

```
[headers-email]
x-priority=type:integer
```

```
[value-actions]
VTIP=url:https://www.virustotal.com/en/ip-address/%TEXT%/information/;name:Virus Total IP;category:ip
VTHOST=url:https://www.virustotal.com/en/domain/%HOST%/information/;name:Virus Total Host;category:host
VTURL=url:https://www.virustotal.com/latest-scan/%URL%;name:Virus Total URL;c
```

  [api]: https://github.com/cisagov/Malcolm#api
  [ftl]: https://github.com/cisagov/Malcolm/blob/main/scripts/third-party-logs/README.md
  [itl]: https://github.com/cisagov/Malcolm#ingesting-third-party-logs
  [las]: https://127.0.0.1/sessions
  [lda]: https://127.0.0.1/dashboards
  [lef]: https://127.0.0.1/extracted-files/
  [lhn]: https://127.0.0.1/name-map-ui/
  [luf]: https://127.0.0.1:488/
  [lup]: https://127.0.0.1/upload
  [mal]: https://github.com/cisagov/Malcolm
  [nfa]: https://github.com/ansv46/nfa.git
  [san]: https://www.sans.org/blog/sans-zoom-backgrounds/
  [upd]: https://github.com/cisagov/Malcolm#UpgradePlan
  [zif]: https://github.com/cisagov/Malcolm#zeek-intelligence-framework
