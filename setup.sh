#!/bin/bash

printf "Upgrade? (Y/n) > "
read input
if [ $input = "Y" ]; then
	{
	apt-get update -y
	apt-get upgrade -y
	} >> /dev/null
fi

printf "Create new user? (Y/n) > "
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

printf "Reconfigure SSH? (Y/n) > "
read input
if [ $input = "Y" ]; then
	printf "Ramdom or custom SSH Port? (Y/<Port>) > "
	read input
	if [ $input = "Y" ]; then
		ssh_port=$(cat /dev/urandom | tr -dc '0-9' | fold -w 4 | head -n 1)
		printf "New SSH Port: $ssh_port"
	else
		ssh_port=$input
	fi
	echo 'Port $ssh_port
Protocol 2
PermitRootLogin no
DebianBanner no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem       sftp    /usr/lib/openssh/sftp-server' > /etc/ssh/sshd_config

fi

printf "Install DNSCrypt-Proxy? (Y/n) > "
read input
if [ $input = "Y" ]; then
	printf "Choose System architecture (arm, x86_64, ..) > "
	read arc
	
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

printf "Install PiHole? (Y/n) > "
read input
if [ $input = "Y" ]; then
	curl -sSL https://install.pi-hole.net | bash
	printf "\nConfiguring PiHole to use DNSCrypt-Proxy...\n"
	#echo "proxy-dnssec" >> /etc/dnsmasq.d/dnscrypt.conf
	sed -i "s/^PIHOLE_DNS_1=.*/PIHOLE_DNS_1=127.0.0.1#5300/gm" /etc/pihole/setupVars.conf
	sed -i "s/^PIHOLE_DNS_2=.*/PIHOLE_DNS_2=::1#5300/gm" /etc/pihole/setupVars.conf
	perl -pi -e 's/^server=(?!(127.0.0.1#5300|::1#5300)).*/server=127.0.0.1#5300/m' -0 /etc/dnsmasq.d/01-pihole.conf
	perl -pi -e 's/^server=(?!(127.0.0.1#5300|::1#5300)).*/server=::1#5300/m' -0 /etc/dnsmasq.d/01-pihole.conf
fi

printf "Install OpenVPN or Wireguard Gateway? (O/W) > "
read VPN
if ! [ -z "$VPN"]; then
	if [ $VPN = "O" ]; then
		iface="tun0"
		printf "Installing OpenVPN...\n"
		apt-get install openvpn -y >> /dev/null
		
		printf "Type in the full path of your OpenVPN config file: "
		$input = ""
		while [ ! -e $input ]; do
			read input
			if [ ! -e $input ]; then
				printf "File could not be found! Try angain: \n"
			fi
		done
		config_file="/etc/openvpn/$(basename "$input").conf"
		cp $input $config_file

		sed -i -E 's/^.*resolv-retry.*$//gm;t;d' $config_file
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

		openvpn --config $config_file --daemon

	elif [ $VPN = "W" ]; then
		iface="wg0"
		printf "Are you on Buster (Y/n)? > "
		read input
		printf "Installing Wireguard...\n"
		if [ $input = "Y" ]; then
			echo "deb http://deb.debian.org/debian/ unstable main" >> /etc/apt/sources.list.d/unstable.list
			apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8B48AD6246925553 
			printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' >> /etc/apt/preferences.d/limit-unstable
			apt update >> /dev/null
		fi

		apt-get install openvpn -y >> /dev/null
		
		printf "Type in the full path of your Wireguard config file: "
		$input = ""
		while [ ! -e $input ]; do
			read input
			if [ ! -e $input ]; then
				printf "File could not be found! Try angain: \n"
			fi
		done
		cp $input /etc/wireguard/wg0.conf
		chown root:root /etc/wireguard/wg0.conf
		chmod 600 /etc/wireguard/wg0.conf
		sed -i "s/^DNS =.*/DNS = 127.0.0.1/gm" /etc/wireguard/wg0.conf

		systemctl enable wg-quick@wg0
		wg-quick up wg0
	fi

	printf "\nConfiguring networking stack...\n"
	printf "Does your VPN Service Support IPv6? (Y/n)"
	read ipv6_support
	printf "#IP Forwarding\nnet.ipv4.ip_forward = 1" > /etc/sysctl.conf
	if [ $ipv6_support = "Y" ]; then
		printf "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
	fi
	echo '#IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
#Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1
#Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0"
#Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
#Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
#Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5" > /etc/sysctl.conf

	sysctl -p /etc/sysctl.conf

	printf "Configuring IP tables...\n"
	printf "Reset IP table chains INPUT, FORWARD and POSTROUTING before adding the new rules? (Y/n) > "
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
	iptables -A FORWARD -o $iface -j ACCEPT
	iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
	if [ $ipv6_support = "Y" ]; then
		ip6tables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
		ip6tables -A FORWARD -i eth0 -o eth0 -j REJECT
		ip6tables -A FORWARD -o $iface -j ACCEPT
		ip6tables -t nat -A POSTROUTING -o $iface -j MASQUERADE
	fi

	apt-get install iptables-persistent -y >> /dev/null
	mkdir /etc/iptables/ -p
	iptables-save /etc/iptables/rules.v4
	if [ $ipv6_support = "Y" ]; then
		ip6tables-save /etc/iptables/rules.v6
	fi
fi

printf "\nDone.\n"
echo "For more advanced configuration visit: https://github.com/Trigus42/Private-LAN/blob/master/guide.md"
