# Optional settings

## Leak testing

### Command line:

#### IP:
```
curl ifconfig.me
```
Output:
```xml
<Your IP>
```
#### DNS:
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

;; Query time: 114 msec
;; SERVER: 127.0.0.1#53(127.0.0.1)
;; WHEN: Fri Jul 31 17:03:53 BST 2020
;; MSG SIZE  rcvd: 62
```

### Browser:

#### IP and DNS:
https://ipleak.net

#### DNS - More detailed :
https://dnsleaktest.com

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