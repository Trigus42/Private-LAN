#!/bin/bash

printf "Update? (Y/n) "
read input
if [ $input = "Y" ]; then
	{
	apt-get update -y
	apt-get upgrade -y
	} >> /dev/null
fi

printf "Create new user? (Y/n) "
read input
if [ $input = "Y" ]; then
	printf "Ramdom or custom name? (Y/<Name>) "
	read input
	if [ $input = "Y" ]; then
		user=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 6 | head -n 1)
	else
		user=$input
	fi
	adduser $user --quiet --gecos None
	adduser $user sudo >> /dev/null
fi

printf "Reconfigure SSH? (Y/n) "
read input
if [ $input = "Y" ]; then
	printf "Ramdom or custom SSH Port? (Y/<Port>) "
	read input
	if [ $input = "Y" ]; then
		ssh_port=$(cat /dev/urandom | tr -dc '0-9' | fold -w 4 | head -n 1)
		printf "New SSH Port: $ssh_port"
	else
		ssh_port=$input
	fi
	printf "Port $ssh_port\nProtocol 2\nPermitRootLogin no\nDebianBanner no\nChallengeResponseAuthentication no\nUsePAM yes\nX11Forwarding yes\nPrintMotd no\nAcceptEnv LANG LC_*\nSubsystem       sftp    /usr/lib/openssh/sftp-server\n" > /etc/ssh/sshd_config
fi

printf "Install DNSCrypt-Proxy? (Y/n) "
read input
if [ $input = "Y" ]; then
	print "Choose System architecture: arm(0), x86_64(1), custom "
	read arc
	if [ arc = "0" ]; then
		arc="arm"
	elif [ arc = 1 ]; then
		arc="x86_64"
	fi
	
	printf "Downloading DNSCrypt-Proxy...\n"
	cd /tmp
	curl -sS https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/latest \
	| grep "browser_download_url.*linux_$arc-.*tar.gz" \
	| cut -d : -f 2,3 \
	| tr -d \" \
	| wget -qi -

	printf "Extracting...\n"
	tar -xf dnscrypt-proxy-linux_$arc-*.tar.gz
	mkdir /etc/dnscrypt-proxy -p
	mv linux-$arc/* /etc/dnscrypt-proxy

	printf "Configuring...\n"
	cp /etc/dnscrypt-proxy/example-dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.toml
	sed -i "s/listen_addresses = \['127\.0\.0\.1:53']/listen_addresses = ['127.0.0.1:5300', '[::1]:5300']/gm" /etc/dnscrypt-proxy/dnscrypt-proxy.toml
	printf "DNSCrypt-Proxy now listening at port 5300\n"

	printf "Installing the service...\n"
	/etc/dnscrypt-proxy/dnscrypt-proxy -service install
	/etc/dnscrypt-proxy/dnscrypt-proxy -service start
	setcap cap_net_bind_service=+pe /etc/dnscrypt-proxy/dnscrypt-proxy
	systemctl enable dnscrypt-proxy
fi

printf "Install PiHole? (Y/n) "
read input
if [ $input = "Y" ]; then
	curl -sSL https://install.pi-hole.net | bash
	printf "\nConfiguring PiHole to use DNSCrypt-Proxy...\n"
	echo "proxy-dnssec" >> /etc/dnsmasq.d/dnscrypt.conf
	sed -i "s/^PIHOLE_DNS_1=.*/PIHOLE_DNS_1=127.0.0.1#5300/gm" /etc/pihole/setupVars.conf
	sed -i "s/^PIHOLE_DNS_2=.*/PIHOLE_DNS_2=::1#5300/gm" /etc/pihole/setupVars.conf
fi

printf "Install OpenVPN Gateway? (Y/n) "
read input
if [ $input = "Y" ]; then
	printf "Installing OpenVPN...\n"
	apt-get install openvpn -y >> /dev/null
	
	printf "Type in the full path of your OpenVPN Config File: "
	$input = ""
	while [ ! -e $input ]; do
		read input
		if [ ! -e $input ]; then
			printf "File could not be found!\n"
		fi
	done
	config_file="/etc/openvpn/$(basename "$input").conf"
	cp $input $config_file

	sed -i -E 's/^.*resolv-retry infinite.*$//gm;t;d' $config_file
	printf "\nresolv-retry infinite" >> $config_file

	sed -i -E 's/^.*keepalive.*$//gm;t;d' $config_file
	printf "\nkeepalive 10 60" >> $config_file
	
	sed -i -E 's/^.*auth-user-pass.*$//gm;t;d' $config_file
	printf "\nauth-user-pass /etc/openvpn/credentials.dat" >> $config_file
	
	touch /etc/openvpn/credentials.dat
	chown root:root /etc/openvpn/credentials.dat
	chmod 600 /etc/openvpn/credentials.dat
	
	printf "Type in your VPN credentials:\nUser: "
	read input
	echo $input >> /etc/openvpn/credentials.dat
	printf "Password: "
	read -s input
	echo $input >> /etc/openvpn/credentials.dat
	
	printf "\nConfiguring networking stack...\n"
	printf "Does your VPN Service Support IPv6? (Y/n)"
	read ipv6_support
	printf "#IP Forwarding\nnet.ipv4.ip_forward = 1" > /etc/sysctl.conf
	if [ $ipv6_support = "Y" ]; then
		printf "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
	fi
	printf "#IP Spoofing protection\nnet.ipv4.conf.all.rp_filter = 1\nnet.ipv4.conf.default.rp_filter = 1\n#Ignore ICMP broadcast requests\nnet.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
	printf "#Ignore ICMP redirects\nnet.ipv4.conf.all.accept_redirects = 0\nnet.ipv6.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
	printf "#Ignore send redirects\nnet.ipv4.conf.all.send_redirects = 0\nnet.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.conf
	printf "#Disable source packet routing\nnet.ipv4.conf.all.accept_source_route = 0\nnet.ipv6.conf.all.accept_source_route = 0\nnet.ipv4.conf.default.accept_source_route = 0\nnet.ipv6.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
	printf "#Block SYN attacks\nnet.ipv4.tcp_syncookies = 1\nnet.ipv4.tcp_max_syn_backlog = 2048\nnet.ipv4.tcp_synack_retries = 2\nnet.ipv4.tcp_syn_retries = 5" >> /etc/sysctl.conf
	sysctl -p /etc/sysctl.conf
	
	printf "Configuring IP tables...\n"
	printf "Reset important IP table chains before adding the new rules? [If you have any blocking rules or policys it may not work otherwise] (Y/n)"
	read input
	if [ $input = "Y" ]; then
		iptables -P INPUT ACCEPT
		iptables -P FORWARD ACCEPT
		iptables -P OUTPUT ACCEPT
		iptables -t nat -P POSTROUTING ACCEPT
		iptables -F
		iptables -t nat -F
		if [ $ipv6_support = "Y" ]; then
			ip6tables -P INPUT ACCEPT
			ip6tables -P FORWARD ACCEPT
			ip6tables -P OUTPUT ACCEPT
			ip6tables -t nat -P POSTROUTING ACCEPT
			ip6tables -F
			ip6tables -t nat -F
		fi
	fi
	
	iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
	iptables -A FORWARD -i eth0 -o eth0 -j REJECT
	iptables -A FORWARD -o tun0 -j ACCEPT
	iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
	if [ $ipv6_support = "Y" ]; then
		ip6tables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
		ip6tables -A FORWARD -i eth0 -o eth0 -j REJECT
		ip6tables -A FORWARD -o tun0 -j ACCEPT
		ip6tables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
	fi
	
	apt-get install iptables-persistent -y >> /dev/null
	mkdir /etc/iptables/ -p
	iptables-save /etc/iptables/rules.v4
	if [ $ipv6_support = "Y" ]; then
		ip6tables-save /etc/iptables/rules.v6
	fi
fi
printf "\nDone.\n"
echo "For more advanced configuration visit: https://discourse.pi-hole.net/t/openvpn-gateway-with-pihole-and-dnscrypt/26367/"´
