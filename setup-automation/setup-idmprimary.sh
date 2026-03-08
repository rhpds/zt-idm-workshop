#!/bin/bash

echo "testing"

tee -a /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

chmod 400 /root/.ssh/config

dnf -y update

echo "Configure the script variables" >> /root/post-run.log
export IDM_PRIMARY_NAME=idmprimary.local
export IDM_REPLICA_NAME=idmreplica..local
export IDM_CLIENT1_NAME=idmclient1.local
export IDM_CLIENT2_NAME=idmclient2.local
export SUBDOMAIN=local
export REALM=${SUBDOMAIN^^}
export NETBIOS=${GUID^^}

# rhel user is already part of wheel
echo "enable bash completion in the root's shell" >> /root/post-run.log
echo "source /etc/profile.d/bash_completion.sh" >> /root/.bashrc

echo "Configure the firewall for IdM Server" >> /root/post-run.log
firewall-cmd --permanent --add-service=dns
firewall-cmd --permanent --add-service=freeipa-4
firewall-cmd --permanent --add-service=freeipa-ldap
firewall-cmd --permanent --add-service=freeipa-ldaps
firewall-cmd --permanent --add-service=freeipa-replication
firewall-cmd --permanent --add-service=freeipa-trust
firewall-cmd --reload

# # add a time server as they aren't provided by default
# # they don't let us out...
# echo "server    time.chu.nrc.ca         iburst" >> /etc/chrony.conf
# echo "server    0.pool.utoronto.ca      iburst" >> /etc/chrony.conf
# echo "server    1.pool.utoronto.ca      iburst" >> /etc/chrony.conf

echo "Install the ipa-server packages" >> /root/post-run.log
dnf -y install ipa-server ipa-server-dns ipa-healthcheck

echo "Create the lab setup scripts" >> /root/post-run.log
tee -a /root/labsetup.sh << EOF
#!/bin/bash
echo "192.168.0.10 $IDM_PRIMARY_NAME" >> /etc/hosts
echo "192.168.0.11 $IDM_REPLICA_NAME" >> /etc/hosts
echo "192.168.0.20 $IDM_CLIENT1_NAME" >> /etc/hosts
echo "192.168.0.21 $IDM_CLIENT1_NAME" >> /etc/hosts
nmcli connection add type ethernet con-name eth1 ifname eth1 ipv4.addresses 192.168.0.10/24 ipv4.method manual connection.autoconnect yes
nmcli connection up eth1

sleep 2
hostnamectl set-hostname $IDM_PRIMARY_NAME
hostnamectl
ping -c 3 $IDM_PRIMARY_NAME
EOF

chmod +x /root/labsetup.sh

tee -a /root/trustednetwork.sh << EOF
#!/bin/bash
mv /etc/named/ipa-ext.conf /etc/named/ipa-ext.\$(date +"%s").bak
tee -a /etc/named/ipa-ext.conf << TRUSTED
acl "trusted_network" { 
    localnets; 
    localhost; 
    192.168.0.0/24; 
};
TRUSTED

mv /etc/named/ipa-options-ext.conf /etc/named/ipa-options-ext.\$(date +"%s").bak
tee -a /etc/named/ipa-options-ext.conf << OPTIONS
allow-recursion { trusted_network; };
allow-query-cache  { trusted_network; };
dnssec-validation yes;
OPTIONS

EOF

chmod +x /root/trustednetwork.sh

echo "Set the timezone" >> /root/post-run.log
timedatectl set-timezone America/Toronto

echo "DONE" >> /root/post-run.log
