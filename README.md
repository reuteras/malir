# malir

My scripts to install [Malcolm][mal] for incident response (IR).

The plan is to start with Malcom and add more functions and tune the installation to make Malcolm even more useful for investigations related to IR and cases where you have pcap-files to investigate.

## Installation

This script is only tested on Ubuntu 22.04 LTS.

Start by cloning the repo and entering it. If you don't have git installed start with **sudo apt install -y git**.

    git clone https://github.com/reuteras/manir.git
    cd manir

Before the installation is finished you will have to logout one time (update group membership for Docker) and reboot the computer one time (updated settings). You have to rerun the **install.sh** script after logging out and rebooting the computer. The **install.sh** script will tell you when to logout and reboot. To start the process run the following command in the manin

    ./install.sh

After the installation is finished you can optionally run the following command to install some additional tools. See the script for more information.

    ./tools.sh

## TODO

- [ ] Add support to tag TOR exit nodes.
- [ ] Try and se if [nfa][nfa] is useful.
- [ ] Add more right-click functionality to Arkime
- [ ] More plugins to Zeek?
- [ ] Zeek [Intelligence Framework][zif] in Malcolm?
- [ ] Look at theA Malcolm [api][api].
- [ ] Read [Ingesting Third-Party Logs][itl] and [Forwarding Third-Party Logs to Malcolm][ftl]
- [ ] Is it useful to have an [update][upd] script for this usecase?

  [api]: https://github.com/cisagov/Malcolm#api
  [ftl]: https://github.com/cisagov/Malcolm/blob/main/scripts/third-party-logs/README.md
  [itl]: https://github.com/cisagov/Malcolm#ingesting-third-party-logs
  [mal]: https://github.com/cisagov/Malcolm
  [nfa]: https://github.com/ansv46/nfa.git
  [upd]: https://github.com/cisagov/Malcolm#UpgradePlan
  [zif]: https://github.com/cisagov/Malcolm#zeek-intelligence-framework
