#!/bin/bash

echo "testing"

tee -a /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

chmod 400 /root/.ssh/config

# rhel user is already part of wheel
echo "enable bash completion in the root's instruqt shell" >> /root/post-run.log
echo "source /etc/profile.d/bash_completion.sh" >> /root/.bashrc

echo "Configure the firewall for IdM Server" >> /root/post-run.log
firewall-cmd --permanent --add-service=dns
firewall-cmd --permanent --add-service=freeipa-4
firewall-cmd --permanent --add-service=freeipa-ldap
firewall-cmd --permanent --add-service=freeipa-ldaps
firewall-cmd --permanent --add-service=freeipa-replication
firewall-cmd --permanent --add-service=freeipa-trust
firewall-cmd --reload

echo "Configure the script variables" >> /root/post-run.log
export IDM_PRIMARY_NAME=idmprimary.${GUID}.${DOMAIN}
export IDM_REPLICA_NAME=idmreplica.${GUID}.${DOMAIN}
export IDM_CLIENT1_NAME=idmclient1.${GUID}.${DOMAIN}
export IDM_CLIENT2_NAME=idmclient2.${GUID}.${DOMAIN}
export SUBDOMAIN=${GUID}.${DOMAIN}
export REALM=${SUBDOMAIN^^}
export NETBIOS=${GUID^^}

echo "Install the ipa-server packages" >> /root/post-run.log
dnf -y install bind-utils
dnf -y install ipa-server ipa-server-dns ipa-healthcheck

echo "Create the lab setup scripts" >> /root/post-run.log
tee -a /root/labsetup.sh << EOF
#!/bin/bash
PRIMARYIPADDRESS=\$(nslookup $IDM_PRIMARY_NAME | awk '/^Address: / { print \$2 }')
MYIPADDRESS=\$(hostname --all-ip-addresses)
echo "\$PRIMARYIPADDRESS $IDM_PRIMARY_NAME" >> /etc/hosts
echo "\$MYIPADDRESS $IDM_REPLICA_NAME" >> /etc/hosts
nmcli conn mod 'Wired connection 1' ipv6.method disabled
nmcli conn up 'Wired connection 1'
sleep 2
hostnamectl set-hostname $IDM_REPLICA_NAME
hostnamectl
ping -c 3 $IDM_REPLICA_NAME
EOF

chmod +x /root/labsetup.sh

tee -a /root/trustednetwork.sh << EOF
#!/bin/bash
CIDR=\$(hostname --all-ip-addresses | cut -d"." -f1-2 | awk '{ print \$1".0.0/22" }')
mv /etc/named/ipa-ext.conf /etc/named/ipa-ext.\$(date +"%s").bak
tee -a /etc/named/ipa-ext.conf << TRUSTED
acl "trusted_network" { 
    localnets; 
    localhost; 
    \$CIDR; 
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
