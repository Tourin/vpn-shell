#!/bin/bash

if [ $(id -u) != "0" ]; then
    printf "Error: You must be root to run this tool!\n"
    exit 1
fi
clear
printf "
####################################################
#                                                  #
# This is a l2tp vpn shell based Zed Lau           #
#                                                  #
# Author: chenwg                                    #
# Website: http://www.chenwg.com                        #
#                                                  #
####################################################
"
vpsip=`hostname -i`
echo "Please input server IP address:"
read -p "(Default IP: &vpsip):" vpsip
if [ "$vpsip" = "" ]; then
	vpsip= &vpsip
fi

iprange="10.0.99"
echo "Please input IP-Range:"
read -p "(Default Range: 10.0.99):" iprange
if [ "$iprange" = "" ]; then
	iprange="10.0.99"
fi

mypsk="tanglin"
echo "Please input PSK:"
read -p "(Default PSK: tanglin):" mypsk
if [ "$mypsk" = "" ]; then
	mypsk="tanglin"
fi



clear
get_char()
{
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}
echo ""
echo "ServerIP:"
echo "$vpsip"
echo ""
echo "Server Local IP:"
echo "$iprange.1"
echo ""
echo "Client Remote IP Range:"
echo "$iprange.2-$iprange.254"
echo ""
echo "PSK:"
echo "$mypsk"
echo ""
echo "Press any key to start..."
char=`get_char`
clear
mknod /dev/random c 1 9
yum -y update
yum -y upgrade
yum install -y ppp iptables make gcc gmp-devel xmlto bison flex xmlto libpcap-devel lsof vim-enhanced
mkdir /ztmp
mkdir /ztmp/l2tp
cd /ztmp/l2tp
wget https://download.openswan.org/openswan/old/openswan-2.6/openswan-2.6.24.tar.gz --no-check-certificate
tar zxvf openswan-2.6.24.tar.gz
cd openswan-2.6.24
make programs install
rm -rf /etc/ipsec.conf
touch /etc/ipsec.conf
cat >>/etc/ipsec.conf<<EOF
config setup
    nat_traversal=yes
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    oe=off
    protostack=netkey
    plutostderrlog=/var/log/ipsec.log
conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT
conn L2TP-PSK-noNAT
    authby=secret
    type=tunnel
    esp=aes128-sha1
    ike=aes128-sha-modp1024
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    left=$vpsip
    leftnexthop=%defaultroute
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    rightsubnetwithin=0.0.0.0/0
    dpddelay=30
    dpdtimeout=120
    dpdaction=clear
EOF
cat >>/etc/ipsec.secrets<<EOF
$vpsip %any: PSK "$mypsk"
EOF
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
sysctl -p
iptables --table nat --append POSTROUTING --jump MASQUERADE
for each in /proc/sys/net/ipv4/conf/*
do
echo 0 > $each/accept_redirects
echo 0 > $each/send_redirects
done
/etc/init.d/ipsec restart
ipsec verify
cd /ztmp/l2tp
wget http://nchc.dl.sourceforge.net/project/rp-l2tp/rp-l2tp/0.4/rp-l2tp-0.4.tar.gz
tar zxvf rp-l2tp-0.4.tar.gz
cd rp-l2tp-0.4
./configure
make
cp handlers/l2tp-control /usr/local/sbin/
mkdir /var/run/xl2tpd/
ln -s /usr/local/sbin/l2tp-control /var/run/xl2tpd/l2tp-control
cd /ztmp/l2tp
wget https://raw.githubusercontent.com/Tourin/vpn-shell/master/xl2tpd-1.2.4.tar.gz
tar zxvf xl2tpd-1.2.4.tar.gz
cd xl2tpd-1.2.4
make install
mkdir /etc/xl2tpd
rm -rf /etc/xl2tpd/xl2tpd.conf
touch /etc/xl2tpd/xl2tpd.conf
cat >>/etc/xl2tpd/xl2tpd.conf<<EOF
[global]
listen-addr = $vpsip
ipsec saref = yes
[lns default]
ip range = $iprange.2-$iprange.254
local ip = $iprange.1
refuse chap = yes
refuse pap = yes
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF
rm -rf /etc/ppp/options.xl2tpd
touch /etc/ppp/options.xl2tpd
cat >>/etc/ppp/options.xl2tpd<<EOF
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
asyncmap 0
auth
crtscts
lock
hide-password
modem
debug
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
idle 1800
mtu 1410
mru 1410
nodefaultroute
connect-delay 5000
logfd 2
logfile /var/log/l2tpd.log
EOF
cat >>/etc/ppp/chap-secrets<<EOF
lolo l2tpd 1216 *
EOF
touch /usr/bin/zl2tpset
echo "#/bin/bash" >>/usr/bin/zl2tpset
echo "for each in /proc/sys/net/ipv4/conf/*" >>/usr/bin/zl2tpset
echo "do" >>/usr/bin/zl2tpset
echo "echo 0 > \$each/accept_redirects" >>/usr/bin/zl2tpset
echo "echo 0 > \$each/send_redirects" >>/usr/bin/zl2tpset
echo "done" >>/usr/bin/zl2tpset
chmod +x /usr/bin/zl2tpset
iptables --table nat --append POSTROUTING --jump MASQUERADE
zl2tpset
xl2tpd
cat >>/etc/rc.local<<EOF
iptables --table nat --append POSTROUTING --jump MASQUERADE
/etc/init.d/ipsec restart
/usr/bin/zl2tpset
/usr/local/sbin/xl2tpd
EOF

clear
ipsec verify
printf "
if there are no [FAILED] above, then you can
connect to your L2TP VPN Server with the default
user/pass below:
ServerIP:$vpsip
username:test
password:test123
PSK:$mypsk
"