## Setup the VPN gateway:

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

### **Edit kernel parameters to enable IP forwarding and enhance security:**  
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

### **Store the VPN credentials in a file:**  
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

    apt install raspberrypi-kernel-headers wireguard

### **Move and rename your config file to /etc/wireguard/wg0.conf:**  

    mv <Server.conf> /etc/openvpn/wg0.conf

### **Only allow root to access the file:**

    chown root:root /etc/wireguard/wg0.conf
    chmod 600 /etc/wireguard/wg0.conf
    
### **Edit DNS server**
*Although devices on your network will use Pi-Hole your server itself will use the DNS server specified in the Wireguard config file. Thus for your server to use Pi-Hole you have to set it to "127.0.0.1":*
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
