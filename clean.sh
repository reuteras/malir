#!/bin/bash

sudo apt-get -y autoremove
sudo apt-get autoclean
sudo apt-get clean
sudo docker system prune --force
