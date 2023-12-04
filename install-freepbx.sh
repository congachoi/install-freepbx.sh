#!/bin/bash -e

#sudo sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config

# set up a swapfile
dd if=/dev/zero of=/1GB.swap bs=1024 count=1048576
mkswap /1GB.swap
chmod 0600 /1GB.swap
swapon /1GB.swap
echo "
/1GB.swap  none  swap  sw 0  0" >> /etc/fstab
echo "
vm.swappiness=10" >> /etc/sysctl.conf

yum -y --quiet update
yum -y --quiet groupinstall core base "Development Tools"
yum -y --quiet remove firewalld
adduser asterisk -m -c "Asterisk User"
yum -y --quiet install lynx tftp-server unixODBC mysql-connector-odbc mariadb-server mariadb httpd ncurses-devel sendmail sendmail-cf sox newt-devel libxml2-devel libtiff-devel audiofile-devel gtk2-devel subversion kernel-devel git crontabs cronie cronie-anacron wget vim uuid-devel sqlite-devel net-tools gnutls-devel python-devel texinfo libuuid-devel
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
yum -y --quiet install php56w php56w-pdo php56w-mysql php56w-mbstring php56w-pear php56w-process php56w-xml php56w-opcache php56w-ldap php56w-intl php56w-soap
curl -sL https://rpm.nodesource.com/setup_8.x | bash -
yum install -y --quiet nodejs
systemctl enable mariadb.service
systemctl start mariadb
mysql_secure_installation
# INTERACTIVE: enter, n, enter, enter, enter, enter, enter

systemctl enable httpd.service
systemctl start httpd.service
# pear install Console_Getopt # already installed
pushd /usr/src
wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
#wget http://downloads.asterisk.org/pub/telephony/libpri/libpri-current.tar.gz
wget -O libpri-current.tar.gz http://downloads.asterisk.org/pub/telephony/libpri/old/libpri-1.6.0.tar.gz
wget -O asterisk-14-current.tar.gz http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-14.7.8.tar.gz
#wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-14-current.tar.gz
wget -O jansson.tar.gz https://github.com/akheron/jansson/archive/v2.10.tar.gz
popd
pushd /usr/src
tar vxfz jansson.tar.gz
rm -f jansson.tar.gz
pushd jansson-*
autoreconf -i
./configure --libdir=/usr/lib64
make
make install
popd
tar xvfz asterisk-14-current.tar.gz
rm -f asterisk-14-current.tar.gz
pushd asterisk-*
contrib/scripts/install_prereq install
./configure --libdir=/usr/lib64 --with-pjproject-bundled
contrib/scripts/get_mp3_source.sh
make menuselect
# INTERACTIVE: select format_mp3, res_config_mysql, cdr_mysql on first page, save and exit

make
make install
make config
ldconfig
chkconfig asterisk off
chown asterisk. /var/run/asterisk
chown -R asterisk. /etc/asterisk
chown -R asterisk. /var/{lib,log,spool}/asterisk
chown -R asterisk. /usr/lib64/asterisk
chown -R asterisk. /var/www/
popd
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php.ini
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/httpd/conf/httpd.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
systemctl restart httpd.service
wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-14.0-latest.tgz
tar xfz freepbx-14.0-latest.tgz
rm -f freepbx-14.0-latest.tgz
pushd freepbx
./start_asterisk start
./install -n
popd
popd
echo "[Unit]
Description=FreePBX VoIP Server
After=mariadb.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/fwconsole start -q
ExecStop=/usr/sbin/fwconsole stop -q
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/freepbx.service
systemctl enable freepbx.service
echo Local IP is: "$(hostname -I)"


# log in to http://your-local-ip
# set password
# set sound prompts to English (United Kingdom)
# Settings → Asterisk SIP settings → External Address → Detect Network Settings → Submit
# Applications → Extensions → Quick Create Extension → PJSIP
# Set extension number, set display name, finish
# Edit extension, set secret to something reasonable, submit
# Apply config (red button, top right)

systemctl restart freepbx # assume just this once, maybe for network settings change

# log in to VoIP app on phone - domain is public IP of server, username is ext number, password is secret