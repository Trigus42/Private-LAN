# VPN Gateway with PiHole and DNSCrypt

*The goal is to set up Pi-Hole as DNS and DHCP server, DNSCrypt-Proxy to encrypt the DNS requests and a VPN gateway.  
I assume that all commands are executed as root, Raspbian Buster or Bullseye is used as operating system and your network interface is named "eth0". If you wan't to use you WiFi network card or another Ethernet interface just replace "eth0" by it's name everywhere.*

## General:

### Interface names:
With **Bullseye** we've got "predictable" interface names. But those are just hampering for our purposes.  
To assign static interface names you have to create this file:
 ```xml
 #/etc/systemd/network/10-persistent-net.link
 [Match]
 MACAddress=<MAC>

 [Link]
 Name=<Custom name>
 ```
 <details>
<summary>Example</summary>
    
 ```xml
 [Match]
 MACAddress=01:23:45:67:89:ab

 [Link]
 Name=eth0
 ```
 </details>
 
 ### Unstable Repos
 If you want to use Wireguard on **Buster** you have to add the "Debian Unstable" repository to your apt sources first:
 ```
echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
wget -O - https://ftp-master.debian.org/keys/archive-key-$(lsb_release -sr).asc | sudo apt-key add -
printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable
apt update
```

## Install DNSCrypt-Proxy:   

### **Download and extract DNSCrypt-Proxy:**  
Newest release: https://github.com/jedisct1/dnscrypt-proxy/releases/  
For the RPi we need the linux-arm version.
```xml
cd /etc
wget <Download Link>
tar -xf dnscrypt-proxy-linux_arm-*.tar.gz
mv linux-arm dnscrypt-proxy
rm dnscrypt-proxy-linux_arm-*.tar.gz
```

### **Configure DNSCrypt-Proxy:**  
```
cd /etc/dnscrypt-proxy
cp example-dnscrypt-proxy.toml dnscrypt-proxy.toml
```
Change in dnscrypt-proxy.toml:
```yaml
## Pi-Hole already uses Port 53
listen_addresses = ['127.0.0.1:5300', '[::1]:5300'] 
## Pi-Hole is our system resolver, which uses DNSCrypt-Proxy itself
ignore_system_dns = true
```
<details>
<summary>Some optional settings</summary>

```xml
server_names = [’ <SERVER NAME1>’, ’ <SERVER NAME2>’] ## If you want to use specific servers
ipv6_servers = false ## “true” if your VPN service supports IPv6
require_dnssec = true # I would recommend it for security reasons
require_nolog = true ## I would recommend it for privacy reasons
fallback_resolver = ‘176.126.70.119:53’ ## OpenNIC; You can use any server you trust

##Insert below “[sources]”:
[sources.’<LIST NAME>’]
urls = [’<List URL>’, ‘<BACKUP URL>’]
minisign_key = ‘<MINISIGN_KEY>’
cache_file = ‘<CACHE FILE (CUSTOM)>’

##Insert below “[anonymized_dns]”:
routes = [
{ server_name=’ <SERVER NAME1>’, via=[’ <RELAY NAME>’,<…>] },
{ server_name=’<SERVER NAME2>’, via=[’ <RELAY NAME>’,<…>] }
]
```
[Server/Relay lists ("Sources")](https://github.com/DNSCrypt/dnscrypt-resolvers/tree/master/v3)  
[More info about the servers](https://github.com/dyne/dnscrypt-proxy/blob/master/dnscrypt-resolvers.csv)
</details>

### **Install the service:**  
    ./dnscrypt-proxy -service install

### **Check your configuration:**  
    ./dnscrypt-proxy -resolve google.com
The output should look something like this:
```
Resolving [google.com]
Domain exists:  yes, 4 name servers found
Canonical name: google.com.
IP addresses:   172.217.23.110, 2a00:1450:4001:800::200e
TXT records:    v=spf1 include:_spf.google.com ~all facebook-domain-verification=22rm551cu4k0ab0bxsw536tlds4h95 docusign=1b0a6754-49b1-4db5-8540-d2c12664b289 globalsign-smime-dv=CDYX+XFHUw2wml6/Gb8+59BsH31KzUr6c1l2BPvqKX8= docusign=05958488-4752-4ef2-95eb-aa7ba8a3bd0e
Resolver IP:    45.87.212.50
```

### **Allow the service to bind to the specified port as non-root user:**  
    setcap cap_net_bind_service=+pe dnscrypt-proxy 

### **Start the service on boot:**  
    systemctl enable dnscrypt-proxy

## Setup the VPN gateway:

### **Edit kernel parameters to enable IP forwarding and enchance security:**  
Uncomment/paste in /etc/sysctl.conf:  
```yaml
#IP Forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding=1 ##If your VPN supports IPv6
#IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
#Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1
#Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
#Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
#Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians=1
```
Load these changes:  

    sysctl -p /etc/sysctl.conf 

*More info about these settings:  
[IP Spoofing](http://tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.kernel.rpf.html)  
[ICMP broadcast requests](https://www.cloudflare.com/learning/ddos/smurf-ddos-attack/)  
[ICMP redirects](https://askubuntu.com/questions/118273/what-are-icmp-redirects-and-should-they-be-blocked)  
[Source packet routing](https://www.ccexpert.us/basic-security-services/disable-ip-source-routing.html)  
[SYN attacks](https://www.symantec.com/connect/articles/hardening-tcpip-stack-syn-attacks)*

<details>
<summary>Setup OpenVPN</summary>

### **Install OpenVPN:**  
    apt install openvpn 

### **Move your config files to /etc/openvpn/:**  
Download the OpenVPN config files from your VPN provider.  
If your server configuration is saved as <Server.conf> in /etc/openvpn/ the connection is automatically initialized during boot.  

    cp <Server.ovpn> /etc/openvpn/<Server>.conf
    mkdir /etc/openvpn/server  
    
If those files exist:  

    mv <CACertificate.crt> /etc/openvpn/server/
    mv <UserCertificate.crt> /etc/openvpn/server/
    mv <PrivateKey.key> /etc/openvpn/server/

### **Store the VPN credentails in a file:**  
Insert in /etc/openvpn/<Server.conf>:

    auth-user-pass /etc/openvpn/server/passwd.conf
    
Create the file:
```xml
echo "<LOGIN NAME> <LOGIN PASSWORD>" > /etc/openvpn/server/passwd.conf
```

Only allow root to access the file:  

    chown root:root /etc/openvpn/server/passwd.conf
    chmod 600 /etc/openvpn/server/passwd.conf

### **Depending on the files you got from your VPN provider you may have to configure certificates or keys:**  
Insert in /etc/openvpn/<Server.conf>:
```
ca /etc/openvpn/server/<CACertificate>.crt
cert /etc/openvpn/server/<UserCertificate>.crt
key /etc/openvpn/server/<PrivateKey>.key
```

### **Configure iptables:**  
```
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth0 -j REJECT
iptables -A FORWARD -s 192.168.178.0/24 -o tun0 -j ACCEPT
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

##If your VPN service supports IPv6
ip6tables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A FORWARD -i eth0 -o eth0 -j REJECT
ip6tables -A FORWARD -s fe80::/10 -o tun0 -j ACCEPT
ip6tables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
```

### **Test the configuration:**  

    openvpn --config /etc/openvpn/<Server>.conf --daemon

</details>

<details>
<summary>Setup Wireguard</summary>

### **Install Wireguard:**

    apt install wireguard

### **Move and rename your config file to /etc/wireguard/wg0.conf:**  

    mv <Server.conf> /etc/openvpn/wg0.conf

### **Only allow root to access the file:**

    chown root:root /etc/wireguard/wg0.conf
    chmod 600 /etc/wireguard/wg0.conf
    
### **Edit DNS server**
*Altough devices on your network will use Pi-Hole your RPi itself will use the DNS server specifyed in the Wireguard config file. Thus for your RPI to use Pi-Hole you have to set it to "127.0.0.1":*
```
#/etc/wireguard/wg0.conf
DNS = 127.0.0.1
```

### **Enable Wireguard to start on boot:**

    systemctl enable wg-quick@wg0

### **Configure iptables:**  
```
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth0 -j REJECT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

##If your VPN service supports IPv6
ip6tables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A FORWARD -i eth0 -o eth0 -j REJECT
ip6tables -A FORWARD -o wg0 -j ACCEPT
ip6tables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
```

### **Test the configuration:**  

    wg-quick up wg0

</details>

### **Save this configuration:**  
Install 'iptables-persistent'

    apt install iptables-persistent

Save the current iptables configuration (In case you didn't already do it during the installation)

    iptables-save > /etc/iptables/rules.v4
    iptables-save > /etc/iptables/rules.v6 ## If your VPN service supports IPv6

## Install Pi-Hole:  
> Our code is completely open, but piping to bash can be dangerous. For a safer install, review the code and then run the installer locally.

    curl -sSL https://install.pi-hole.net | bash 

For this guide it's irrelevant what you choose in the installer.

### **Configure the Interface:**  
In case you didn't already set up your interface during the Pi-Hole installation, paste and overwrite any existing configuration for eth0 in /etc/dhcpcd.conf:  
```yaml
interface eth0
static ip_address=<IP> ##The IP adress you want your RPi to have
static routers=<IP> ##The IP adress of your router
static domain_name_servers=127.0.0.1
``` 

### **Activate DNSSEC:** 
If DNSSEC is activated in DNSCrypt-Proxy, you should activate it in dnsmasq too:

    echo "proxy-dnssec" > /etc/dnsmasq.d/dnscrypt.conf 

### **Configure DHCP and DNS:**  
**Turn off the DHCP server of your router first.**  
In the Pi-Hole web interface:
- Settings &rightarrow; DNS &rightarrow;  
&nbsp;&nbsp;&rightarrow; Disable all "Upstream DNS Servers"  
&nbsp;&nbsp;&rightarrow; Enable Custom 1 (IPv4); Fill in ```127.0.0.1#5300```  
&nbsp;&nbsp;&rightarrow; Enable Custom 3 (IPv6); Fill in ```::1#5300```  
- Settings &rightarrow; DHCP &rightarrow; DHCP server enabled:heavy_check_mark: | Router (gateway) IP address: <IP of the RPi (eth0)> &rightarrow; Save

  If DNSSEC is activated in DNSCrypt-Proxy:
- Settings &rightarrow; DNS &rightarrow; Use DNSSEC:heavy_check_mark: &rightarrow; Save  

---


# Optional settings

## System:

### **unattended-upgrades:**

Once the server is set up you shouldn't have to worry about security updates.  
"unattended-upgrades" frequently checks for - and installs - security updates.  
```
apt install unattended-upgrades apt-listchanges
dpkg-reconfigure -plow unattended-upgrades
```

## [dnsmasq:](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)

### **Exclude Devices**:

<details>
<summary>Using different IP Ranges</summary>

/etc/dnsmasq.d/02-pihole-dhcp.conf:  
```xml
dhcp-authoritative

#Default IP Range
dhcp-range=<Start IP>,<End IP>,24h

#IP Range 2
dhcp-range=set:tag0,<Start IP>,<End IP>,24h

#Settings of Default IP Range
dhcp-option=3,<Gateway>
dhcp-option=6,<DNS Server>

#Settings of IP Range 2
dhcp-option=tag:tag0,3,<Gateway>
dhcp-option=tag:tag0,6,<DNS Server>

dhcp-leasefile=/etc/pihole/dhcp.leases
#quiet-dhcp
domain=lan

dhcp-rapid-commit
```

Write-protect this file so you can't accidentally overwrite it using the Pi-Hole DHCP configurator.  
To unlock the file replace the '+' by a '-'.

    chattr +i 02-pihole-dhcp.conf

Align IP addresses in the IP range's to the devices.

04-pihole-static-dhcp.conf:
```xml
dhcp-host=<MAC address>,<IP address>,<NAME>
```

<details>
<summary>Example</summary>

/etc/dnsmasq.d/02-pihole-dhcp.conf:
```
dhcp-authoritative
#VPN
dhcp-range=set:tag0,92.168.0.10,192.168.0.99,24h
dhcp-option-force=tag:tag0,3,192.168.0.2
dhcp-option=tag:tag0,6,192.168.0.2

#Direct
dhcp-range=set:tag1,192.168.0.100,192.168.0.199,24h
dhcp-option=tag:tag1,3,192.168.0.1
dhcp-option=tag:tag1,6,192.168.0.2

dhcp-leasefile=/etc/pihole/dhcp.leases
#quiet-dhcp
domain=lan

dhcp-rapid-commit
```
04-pihole-static-dhcp.conf: 
```
dhcp-host=81:7d:22:a2:3e:7d,192.168.0.10,VPN-Computer
dhcp-host=81:7d:22:a2:3e:7e,192.168.0.100,Computer
```
</details>
</details>

<details>
<summary>Using tags only</summary>

Insert in /etc/dnsmasq.d/02-pihole-dhcp.conf:
```xml
dhcp-option=tag:<tag>,3,<Gateway>
```

04-pihole-static-dhcp.conf:  
```xml
dhcp-host=<MAC address>,<IP address>,<NAME>,set:<tag>
```

<details>
<summary>Example</summary>

In /etc/dnsmasq.d/02-pihole-dhcp.conf:
```
dhcp-option=tag:Direct,3,192.168.0.1
dhcp-option=tag:VPN,3,192.168.0.2
```

04-pihole-static-dhcp.conf:  
```
dhcp-host=81:7d:22:a2:3e:7d,192.168.0.10,VPN-Computer,set:VPN
dhcp-host=81:7d:22:a2:3e:7e,192.168.0.10,Computer,set:Direct
```
</details>
</details>

## [iptables:](https://linux.die.net/man/8/iptables)
**Important:**  
- IP-Tables rules are processed in the given order. To block a request for example, the corresponding rule must be set before the rule that generally allows requests of this type.
- If you are using OpenVPN you have to replace wg0 by tun0 in the rules.

### **Set up a simple firewall:**

Thanks to iptables-persistent, editing the configuration is simple.  
Depending on the configuration you edit (rules.v4/rules.v6) you just need to use the correct IP format (IPv4/IPv6) when it comes to your LAN IP range.

/etc/iptables/rules.v*:
```xml
*filter
:INPUT DROP
:TRUSTED_IP DROP
:FORWARD DROP
:OUTPUT ACCEPT

-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp --icmp-type 8 -j ACCEPT
-A INPUT -p udp --dport 67:68 -j ACCEPT
-A INPUT -s <LAN IP range> -j TRUSTED_IP

-A TRUSTED_IP -p udp --dport 53 -j ACCEPT
-A TRUSTED_IP -p icmp -j ACCEPT
-A TRUSTED_IP -p tcp --dport 80 -j ACCEPT
-A TRUSTED_IP -p tcp --dport <SSH Port> -j ACCEPT
-A TRUSTED_IP -j REJECT

-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
#-A FORWARD --match multiport ! --dports <Allowed Ports> -o wg0 -j REJECT
-A FORWARD -s <LAN IP range> -o wg0 -j ACCEPT

COMMIT

*nat
:PREROUTING ACCEPT
:INPUT ACCEPT
:POSTROUTING ACCEPT
:OUTPUT ACCEPT

-A POSTROUTING -o wg0 -j MASQUERADE

COMMIT
```
*Example IP ranges:  
IPv4: 192.168.0.0/24  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [192.168.0.1 - 192.168.0.255]  
IPv6: 2001:db8::/32  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[2001:db8:0:0:0:0:0:0 - 2001:db8:ffff:ffff:ffff:ffff:ffff:ffff]*

<details>
<summary>What does it do?</summary>

## filter:
- Drop incoming connections by default

INPUT:
- Allow packets being sent to the loopback interface
- Allow packets of self-established connections or connections related to those
- Allow pings
- Allow DHCP packets
- Pass packets coming from your LAN IP range to the "TRUSTED_IP" chain
  
TRUSTED_IP:
- Allow packets of incoming DNS requests (UDP)
- Allow ICMP packets
- Allow http connections (Pi-Hole web interface)
- Allow SSH connections
- REJECT other packets (no timeout on the client side)

FORWARD:
- Allow packets of self-established connections or connections related to those
- Drop all packets not sent over one of the specified ports
- Allow packet forwarding from your LAN to the VPN interface

## nat:
- Accept all packets by default
- Replace your clients local by your RPi's public IP and the other way around (Essentially how all routers work)
</details>

### **Rules for specific devices:**

Since the devices connect to the internet over the Raspberry your routers filters are being bypassed.  
The safest way is to use the module 'mac', because the MAC is usually (Windows, Android, IOS, Linux) either not changeable at all, or only with root access.

This rule blocks requests to the RPi.

    -A INPUT -m mac --mac-source <MAC> -j REJECT

This rule blocks the devices internet connection over the RPi.

    -A FORWARD -m mac --mac-source <MAC> -j REJECT

Of course if you use static IP you could also specify the device by its IP:

    -A INPUT -s <IP> -j REJECT

### **Timed rules:**

The most direct solution is via the 'time' module.  
This rule blocks a request between 22:00 and 06:00, Sunday to Thursday:

    -A INPUT -m time --timestart 22:00 --timestop 06:00 --weekdays Sun,Mon,Tue,Wed,Thu -j REJECT


If you want whole rule sets to change, you could also load them via cron.  
Sample configuration for /etc/cron.d/iptables:
```
00 00 * * * root /usr/sbin/iptables-restore /etc/iptables/rules.v4
00 00 * * * root /usr/sbin/ip6tables-restore ip6tables-restore /etc/iptables/rules.v6
00 12 * * * root /usr/sbin/iptables-restore /etc/iptables/rules2.v4
00 12 * * * root /usr/sbin/ip6tables-restore ip6tables-restore /etc/iptables/rules2.v6
```
Cron syntax:
```

*     *     *     *     *  Command to be executed
-     -     -     -     -
|     |     |     |     |

|     |     |     |     +----- Weekday (0 - 7) (Sunday corresponds to 0 and 7)

|     |     |     +------- month (1 - 12)

|     |     +--------- day (1 - 31)

|     +----------- hour (0 - 23)

+------------- minute (0 - 59)
```

PS: Don't forget to set your time-zone first.

### **Block certain Domains:**
**Pi-Hole 5 supports specifying black and whitelists for individual devices so there is no need to use iptables anymore if you don't need to filter by MAC or want to set timed rules.**

This rule discards all UDP DNS requests other than "wikipedia.com":

    -A INPUT -p upd --dport 53 -m string ! --string "wikipedia.com" --algo bm -j DROP

It is also possible to filter using Regex. To do this, you must first [install DKMS](https://github.com/smcho-kr/kpcre/wiki/Step-by-step-installation-guide).  
However the algorithm for regex matching is much more complex than the Boyer-Moore algorithm. The rule should therefore be as precise as possible so that the regex matching can be skipped for non-applicable packets.

This rule filters all UDP DNS requests for "*.googlevideo.*" and "googlevideo.*". The syntax of the string is "/[<*REGEX*>](https://regex101.com/)/".

    -A INPUT -p udp --dport 53 -m string --string "/(.*\.|)googlevideo\..*/" --algo regex -j DROP

### **Sample configuration:**
```
*filter
:INPUT DROP
:TRUSTED_IP DROP
:DNS DROP
:FORWARD DROP
:DNS_FORWARD DROP
:OUTPUT ACCEPT

-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp --icmp-type 8 -j ACCEPT
-A INPUT -p udp --dport 67:68 -j ACCEPT
-A INPUT -s 192.168.0.0/24 -j TRUSTED_IP

-A TRUSTED_IP -p udp --dport 53 -j DNS
-A TRUSTED_IP -p icmp -j ACCEPT
-A TRUSTED_IP -p tcp --dport 80 -j ACCEPT
-A TRUSTED_IP -p tcp --dport 22 -j ACCEPT
-A TRUSTED_IP -j REJECT

-A DNS -m mac --mac-source 81:7d:22:a2:3e:7d -m time --timestart 00:00 --timestop 06:00 --weekdays Sun,Mon,Tue,Wed,Thu -m string ! --string "/(.*\.|)whatsapp\.(net|com)|(.*\.|)(signal|whispersystems)\.org/" --algo regex -j REJECT
-A DNS -j ACCEPT

-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A FORWARD -p udp --dport 53 -j DNS_FORWARD
-A FORWARD -p tcp --dport 53 -j DNS_FORWARD
#-A FORWARD --match multiport ! --dports 80,443,53,20,115,143,993 -o wg0 -j REJECT
-A FORWARD -s 192.168.0.0/24 -o wg0 -j ACCEPT

-A DNS_FORWARD -m mac --mac-source 81:7d:22:a2:3e:7d -j REJECT
-A DNS_FORWARD -j ACCEPT

COMMIT

*nat
:PREROUTING ACCEPT
:INPUT ACCEPT
:POSTROUTING ACCEPT
:OUTPUT ACCEPT

-A POSTROUTING -o wg0 -j MASQUERADE

COMMIT
```

# Leak testing

## Command line:

### IP:
```
curl ifconfig.me
```
Output:
```xml
<Your IP>
```
### DNS:
```
dig whoami.akamai.net
```
Output:
```xml
; <<>> DiG 9.11.5-P4-5.1+deb10u1-Raspbian <<>> whoami.akamai.net
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 45507
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;whoami.akamai.net.             IN      A

;; ANSWER SECTION:
whoami.akamai.net.      180     IN      A       <Currently used DNS server>

;; Query time: 1143 msec
;; SERVER: 127.0.0.1#53(127.0.0.1)
;; WHEN: Fri Jul 31 17:03:53 BST 2020
;; MSG SIZE  rcvd: 62
```

## Browser:

### IP and DNS:
https://ipleak.net

### DNS - More detailed :
https://dnsleaktest.com
