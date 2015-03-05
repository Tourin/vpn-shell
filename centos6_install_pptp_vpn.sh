#############################################
#file:pptp vpn installing script
#author:tanglin
#version 1.0
#description:install_pptp_vpn.sh is a free software, 
#it's for auto installing vpn in Redhat AS6 or Centos6
#9drops web site: codingnote.net
#weibo:zhanbz@hotmail.com
#############################################


#!/bin/bash

clear() {
	if [[ `service pptpd status` = *"pid"* ]] ;then
		service pptpd stop
	fi

	yum remove -y pptpd ppp
	iptables --flush POSTROUTING --table nat
	iptables --flush FORWARD

	if [[ `iptables --list-rules|grep 'A INPUT -i eth0 -p gre -j ACCEPT '` = *"-A INPUT -i eth0 -p gre -j ACCEPT "* ]] ;then
		iptables -D INPUT -i eth0 -p gre -j ACCEPT
	fi

	if [[ `iptables --list-rules|grep 'A INPUT -i eth0 -p tcp -m tcp --dport 1723 -j ACCEPT'` = *"A INPUT -i eth0 -p tcp -m tcp --dport 1723 -j ACCEPT"* ]] ;then
		iptables -D INPUT -i eth0 -p tcp -m tcp --dport 1723 -j ACCEPT
	fi

	service iptables save

	if [ -f /etc/pptpd.conf ] ;then
		rm -rf /etc/pptpd.conf
	fi

	if [ -d /etc/ppp ] ;then
		rm -rf /etc/ppp
	fi

	sed '/[ip_forward][ppp]/d' /etc/rc.local > /tmp/rc.local.tmp
	if ! [ -f /etc/rc.local.old ] ;then
		mv -f /etc/rc.local /etc/rc.local.old
	fi

	mv -f /tmp/rc.local.tmp /etc/rc.local
	
	if [ -s /etc/rc.modules ] ;then
		sed '/modprobe tun/d' /etc/rc.modules > /tmp/rc.modules.tmp
		if ! [ -f /etc/rc.modules.old ] ;then
			mv -f /etc/rc.modules /etc/rc.modules.old
		fi

		if [ -s /tmp/rc.modules.tmp ] ;then
			mv -f /tmp/rc.modules.tmp /etc/rc.modules
		fi
	else
		rm -f /etc/rc.modules
	fi
}


install() {

	echo 'modprobe tun' >> /etc/rc.modules
	chmod +x /etc/rc.modules
	
	clear
	rpm -Uhv http://poptop.sourceforge.net/yum/stable/rhel6/pptp-release-current.noarch.rpm
	yum -y install make libpcap iptables gcc-c++ logrotate tar cpio perl pam tcp_wrappers dkms kernel_ppp_mppe ppp pptpd
	
	mknod /dev/ppp c 108 0
	echo 1 > /proc/sys/net/ipv4/ip_forward
	echo "mknod /dev/ppp c 108 0" >> /etc/rc.local
	echo "echo 1 > /proc/sys/net/ipv4/ip_forward" >> /etc/rc.local
	echo "localip 172.16.36.1" >> /etc/pptpd.conf
	echo "remoteip 172.16.36.2-254" >> /etc/pptpd.conf
	echo "ms-dns 8.8.8.8" >> /etc/ppp/options.pptpd
	echo "ms-dns 8.8.4.4" >> /etc/ppp/options.pptpd
	echo "$1    pptpd	$2    *" >> /etc/ppp/chap-secrets
	
	# get default gateway eth
	gwEth=$(route -n |grep '^0.0.0.0' |awk '{print $NF}')
	iptables -A INPUT -i $gwEth -p tcp --dport 1723 -j ACCEPT
	iptables -A INPUT -i $gwEth -p gre -j ACCEPT
	iptables -t nat -A POSTROUTING -o $gwEth -j MASQUERADE
	iptables -A FORWARD -p tcp -s 172.16.36.0/24 -j TCPMSS --syn --set-mss 1356
	service iptables save
	service iptables restart 
	
	chkconfig iptables on
	chkconfig pptpd on
	
	service iptables start
	service pptpd start

}



check() {
	touch /etc/rc.local
	if ! [ $? -eq 0 ] ;then
		echo "Permission denied, please use root user."
		exit 0
	fi

	if ! [ -s /etc/redhat-release ] || ! [[ `grep '6.' /etc/redhat-release` = *"6."* ]] ;then
		echo "Error, your system isn't CentOS 6 or Redhat AS 6."
		exit 0
	fi
}


check
case $1 in
	install)
		if ! [ $# -eq 3 ] ;then
			echo "Usage:sh $0 install vpnname vpnpassword"
			exit 0
		fi
		
		echo "pptpd vpn install..."
		install $2 $3
		echo "install completed."
	
	;;
	uninstall)
		echo "pptpd vpn uninstall..."
		clear
		echo "uninstall completed."
	;;
	*)
		echo "Usage:sh $0 install vpnname vpnpassword"
		echo "or"
		echo "Usage:sh $0 uninstall"
	;;
esac
