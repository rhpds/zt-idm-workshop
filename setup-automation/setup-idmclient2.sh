#!/bin/bash

echo "testing"

tee -a /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

chmod 400 /root/.ssh/config

dnf -y update

echo "Configure idm network"
export IDM_PRIMARY_NAME=idmprimary.example.local
export IDM_REPLICA_NAME=idmreplica.example.local
export IDM_CLIENT1_NAME=idmclient1.example.local
export IDM_CLIENT2_NAME=idmclient2.example.local
export SUBDOMAIN=local
export REALM=${SUBDOMAIN^^}
export NETBIOS=${GUID^^}

echo "192.168.0.10 $IDM_PRIMARY_NAME" >> /etc/hosts
echo "192.168.0.11 $IDM_REPLICA_NAME" >> /etc/hosts
echo "192.168.0.20 $IDM_CLIENT1_NAME" >> /etc/hosts
echo "192.168.0.21 $IDM_CLIENT2_NAME" >> /etc/hosts
hostnamectl set-hostname idmclient2.example.local
nmcli conn mod "Wired connection 2" ipv4.addresses 192.168.0.21/24 ipv4.dns 192.168.0.10 ipv4.method manual connection.autoconnect yes
nmcli conn up "Wired connection 2" 
nmcli conn mod "Wired connection 1" ipv4.dns 192.168.0.10
nmcli conn up "Wired connection 1" 

# Enable cockpit functionality in showroom.
echo "[WebService]" > /etc/cockpit/cockpit.conf
echo "Origins = https://cockpit-${GUID}.${DOMAIN}" >> /etc/cockpit/cockpit.conf
echo "AllowUnencrypted = true" >> /etc/cockpit/cockpit.conf
systemctl enable --now cockpit.socket

echo "enable bash completion in the root's shell" >> /root/post-run.log
echo "source /etc/profile.d/bash_completion.sh" >> /root/.bashrc

echo "Install the ipa-client packages and lab packages" >> /root/post-run.log
dnf -y install firewalld bind-utils net-tools ipa-client

echo "Configure the firewall for httpd" >> /root/post-run.log
systemctl enable --now firewalld
firewall-cmd --permanent --add-service http
firewall-cmd --reload

chmod +x /root/labsetup.sh

echo "Set the timezone" >> /root/post-run.log
timedatectl set-timezone America/Toronto

echo "DONE" >> /root/post-run.log
