#!/bin/bash

echo "testing"

tee -a /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

chmod 400 /root/.ssh/config

# Enable cockpit functionality in showroom.
echo "[WebService]" > /etc/cockpit/cockpit.conf
echo "Origins = https://idmclient2-${GUID}.${DOMAIN}" >> /etc/cockpit/cockpit.conf
echo "AllowUnencrypted = true" >> /etc/cockpit/cockpit.conf
systemctl enable --now cockpit.socket

echo "enable bash completion in the root's instruqt shell" >> /root/post-run.log
echo "source /etc/profile.d/bash_completion.sh" >> /root/.bashrc

echo "Configure the firewall for httpd" >> /root/post-run.log
firewall-cmd --permanent --add-service http
firewall-cmd --reload

echo "Configure the script variables" >> /root/post-run.log
export IDM_SERVER_NAME=idmprimary.${GUID}.${DOMAIN}
export IDM_REPLICA_NAME=idmreplica.${GUID}.${DOMAIN}
export IDM_CLIENT1_NAME=idmclient1.${GUID}.${DOMAIN}
export IDM_CLIENT2_NAME=idmclient2.${GUID}.${DOMAIN}

echo "Install the ipa-client packages" >> /root/post-run.log
dnf -y install bind-utils
dnf -y install ipa-client

echo "Install http for sample app" >> /root/post-run.log
dnf -y install httpd mod_wsgi
rm -f /etc/httpd/conf.d/welcome.conf

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
