#!/bin/sh
echo "Starting module called 01-introduction" >> /tmp/progress.log
IDM=\$(hostname --all-ip-addresses)
echo "\$IDM $IDM_SERVER_NAME" >> /etc/hosts
nmcli conn mod 'Wired connection 1' ipv6.method disabled
nmcli conn up 'Wired connection 1'
sleep 2
hostnamectl set-hostname $IDM_SERVER_NAME
hostnamectl
ping -c 3 $IDM_SERVER_NAME