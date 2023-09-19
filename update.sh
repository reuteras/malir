#!/bin/bash

function update-zeek-intel-critical-path-security(){
    cd ~/Malcolm/zeek/intel/Zeek-Intelligence-Feeds || exit
    git fetch origin master
    git reset --hard FETCH_HEAD
    git clean -df 
}

update-zeek-intel-critical-path-security
