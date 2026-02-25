#!/bin/bash

echo "testing"

tee -a /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

chmod 400 /root/.ssh/config

dnf -y update

echo "Configure the script variables" >> /root/post-run.log
# naming based on deployment names e.g. idmreplica.lab.sandbox-mpkfh-zt-rhelbu.svc.cluster.local
export IDM_PRIMARY_NAME=idmprimary.lab.sandbox-${GUID}-zt-rhelbu.svc.cluster.local
export IDM_REPLICA_NAME=idmreplica.lab.sandbox-${GUID}-zt-rhelbu.svc.cluster.local
export IDM_CLIENT1_NAME=idmclient1.lab.sandbox-${GUID}-zt-rhelbu.svc.cluster.local
export IDM_CLIENT2_NAME=idmclient2.lab.sandbox-${GUID}-zt-rhelbu.svc.cluster.local
export SUBDOMAIN=lab.sandbox-${GUID}-zt-rhelbu.svc.cluster.local

# Enable cockpit functionality in showroom.
echo "[WebService]" > /etc/cockpit/cockpit.conf
echo "Origins = https://cockpit-${GUID}.${DOMAIN}" >> /etc/cockpit/cockpit.conf
echo "AllowUnencrypted = true" >> /etc/cockpit/cockpit.conf
systemctl enable --now cockpit.socket

echo "enable bash completion in the root's shell" >> /root/post-run.log
echo "source /etc/profile.d/bash_completion.sh" >> /root/.bashrc

echo "Configure the firewall for httpd" >> /root/post-run.log
firewall-cmd --permanent --add-service http
firewall-cmd --reload

echo "Install the ipa-client packages" >> /root/post-run.log
dnf -y install bind-utils
dnf -y install ipa-client

echo "Create the lab setup script" >> /root/post-run.log
tee -a /root/labsetup.sh  << EOF
#!/bin/bash
PRIMARYADDRESS=\$(nslookup $IDM_PRIMARY_NAME | awk '/^Address: / { print \$2 }')
REPLICAADDRESS=\$(nslookup $IDM_REPLICA_NAME | awk '/^Address: / { print \$2 }')
nmcli conn mod 'Wired connection 1' ipv4.ignore-auto-dns yes
nmcli conn mod 'Wired connection 1' ipv4.dns \$PRIMARYADDRESS,\$REPLICAADDRESS
nmcli conn mod 'Wired connection 1' ipv6.method disabled
nmcli conn up 'Wired connection 1'
nmcli conn mod 'Wired connection 1' ipv4.ignore-auto-dns yes
nmcli conn up 'Wired connection 1'
sleep 5
hostnamectl set-hostname $IDM_CLIENT2_NAME
hostnamectl
nslookup $IDM_CLIENT2_NAME
EOF


chmod +x /root/labsetup.sh

echo "Set the timezone" >> /root/post-run.log
timedatectl set-timezone America/Toronto

echo "DONE" >> /root/post-run.log
