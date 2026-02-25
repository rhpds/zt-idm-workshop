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
echo "Origins = https://idmclient1-${GUID}.${DOMAIN}" >> /etc/cockpit/cockpit.conf
echo "AllowUnencrypted = true" >> /etc/cockpit/cockpit.conf
systemctl enable --now cockpit.socket

echo "enable bash completion in the root's instruqt shell" >> /root/post-run.log
echo "source /etc/profile.d/bash_completion.sh" >> /root/.bashrc

echo "Configure the firewall for httpd" >> /root/post-run.log
firewall-cmd --permanent --add-service http
firewall-cmd --reload

echo "Install the ipa-client packages" >> /root/post-run.log
dnf -y install bind-utils
dnf -y install ipa-client

echo "Install http for sample app" >> /root/post-run.log
dnf -y install httpd mod_wsgi
rm -f /etc/httpd/conf.d/welcome.conf

echo "Create the sample app" >> /root/post-run.log
tee -a /usr/share/httpd/app.py << EOF
def application(environ, start_response):
    start_response('200 OK', [('Content-Type', 'text/plain')])
    remote_user = environ.get('REMOTE_USER')
    if remote_user is not None:
        yield "LOGGED IN AS: {}\n".format(remote_user).encode('utf8')
    else:
        yield b"NOT LOGGED IN\n"
    yield b"\nREMOTE_* REQUEST VARIABLES:\n\n"
    for k, v in environ.items():
        if k.startswith('REMOTE_'):
            yield "  {}: {}\n".format(k, v).encode('utf8')
EOF

echo "Configure the sample app" >> /root/post-run.log
tee -a /etc/httpd/conf.d/app.conf << EOF
<VirtualHost *:80>
    ServerName $IDM_CLIENT1_NAME
    WSGIScriptAlias / /usr/share/httpd/app.py
    <Directory /usr/share/httpd>
        <Files "app.py">
            Require all granted
        </Files>
    </Directory>
</VirtualHost>
EOF

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
hostnamectl set-hostname $IDM_CLIENT1_NAME
hostnamectl
nslookup $IDM_CLIENT1_NAME
EOF

chmod +x /root/labsetup.sh

echo "Set the timezone" >> /root/post-run.log
timedatectl set-timezone America/Toronto

echo "DONE" >> /root/post-run.log
