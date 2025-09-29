#!/bin/bash

UBT_NET=6
RH_NET=7
SS_NET=17

_NET=$RH_NET


# sshpass -p "changeme" ssh root@192.168.0.90 "shutdown -h now"

for i in `seq 1 5`
do

    sshpass -p "changeme" ssh root@192.168.0.$_NET$i "shutdown -h now"

done

