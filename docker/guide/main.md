# Static Interface configuration:
Paste this and overwrite any existing configuration for eth0 in /etc/dhcpcd.conf: 

```yaml
interface eth0
static ip_address=<IP> ##The IP address you want your server to have
static routers=<IP> ##The IP address of your router
static domain_name_servers=8.8.8.8 1.1.1.1
``` 

<details>
<summary>Example</summary>

```yaml
interface eth0
static ip_address=192.168.0.2
static routers=192.168.0.1
static domain_name_servers=8.8.8.8 1.1.1.1
``` 
</details>

# Setup Docker

#### Install Docker Engine:

    $ curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    $ sh /tmp/get-docker.sh

#### Install Docker Compose:

    $ apt install python3-pip -y && pip3 install docker-compose

#### Enable Docker to start on boot:

    $ systemctl enable docker


# Install Wireguard
#### Install the Wireguard kernel module if your are on Debain Buster or lower :

```
$ echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
$ wget -O - https://ftp-master.debian.org/keys/archive-key-$(lsb_release -sr).asc | sudo apt-key add -
$ printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable
$ apt update
```
On Rapberry PI OS run:

    $ apt install raspberrypi-kernel-headers wireguard -y

On any standard Debian installation run:

    $ apt install linux-headers-$(uname -r) wireguard -y

#### If you are on Bullseye or higher run:

    $ apt install wireguard -y

# Prepare the volumes

#### Create the volume folders:

    $ mkdir -p /etc/private-lan/volumes
    $ cd /etc/private-lan/volumes
    $ mkdir dnscrypt-proxy wireguard-gateway etc-pihole etc-dnsmasq.d

#### Get config files:

    $ git clone https://github.com/Trigus42/Private-LAN /tmp/private-lan
    $ mv /tmp/private-lan/docker/files/etc/* /etc/private-lan/

#### Configure DNSCrypt-Proxy:

    $ wget https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/release/dnscrypt-proxy/example-dnscrypt-proxy.toml -O /etc/private-lan/volumes/dnscrypt-proxy/dnscrypt-proxy.toml

Change in ``/etc/private-lan/volumes/dnscrypt-proxy/dnscrypt-proxy.toml``:
```yaml
listen_addresses = ['0.0.0.0:5300'] 
```
<details>
<summary>Examples for some optional settings</summary>

```xml
server_names = [’ <SERVER NAME1>’, ’ <SERVER NAME2>’] ## If you want to use specific servers
ipv6_servers = false ## “true” if your VPN service supports IPv6
require_dnssec = true # I would recommend it for security reasons
require_nolog = true ## I would recommend it for privacy reasons

## Insert below “[sources]”:
[sources.’<LIST NAME>’]
urls = [’<List URL>’, ‘<BACKUP URL>’]
minisign_key = ‘<MINISIGN_KEY>’
cache_file = ‘<CACHE FILE (CUSTOM)>’

## No really needed because the request are already sent over the VPN
## Insert below “[anonymized_dns]”:
routes = [
{ server_name=’ <SERVER NAME1>’, via=[’ <RELAY NAME>’,<…>] },
{ server_name=’<SERVER NAME2>’, via=[’ <RELAY NAME>’,<…>] }
]
```
[Server/Relay lists ("Sources")](https://github.com/DNSCrypt/dnscrypt-resolvers/tree/master/v3)  
[More info about the servers](https://github.com/dyne/dnscrypt-proxy/blob/master/dnscrypt-resolvers.csv)
</details>

#### Configure Wireguard

Download your config file and place it in ```/etc/private-lan/volumes/wireguard-gateway``` as ```wg0.conf```.  
Insert the following lines in the Wireguard config file below `[Interface]`:
```
# Don't allow forwarding from eth0 to eth0 (bypassing the VPN gateway)
PreUp = iptables -I FORWARD -i eth0 -o eth0 -j REJECT
# Replace the source IP of packets going out trough the Wireguard interface AND add a route to your subnet (https://unix.stackexchange.com/questions/615255/docker-container-as-network-gateway)
PostUp = iptables -t nat -A POSTROUTING -o  %i -j MASQUERADE && ip route add <Your Subnet> via 172.16.238.1
PostDown = iptables -t nat -D POSTROUTING -o  %i -j MASQUERADE && ip route delete <Your Subnet> via 172.16.238.1
```

<details>
<summary>Example</summary>

```
[Interface]
PrivateKey = ...
Address = 100.64.67.64/32
DNS = 10.255.255.3

PreUp = iptables -I FORWARD -i eth0 -o eth0 -j REJECT
PostUp = iptables -t nat -A POSTROUTING -o  %i -j MASQUERADE && ip route add 192.168.0.0/24 via 172.16.238.1
PostDown = iptables -t nat -D POSTROUTING -o  %i -j MASQUERADE && ip route delete 192.168.0.0/24 via 172.16.238.1

[Peer]
PublicKey = ...
AllowedIPs = 0.0.0.0/0
Endpoint = lon-229-wg.whiskergalaxy.com:443
PresharedKey = ...
```
</details>

Assign permissions and ownership (No one but root should be able to see Private Key and PSK):

    $ chown -R root /etc/private-lan/volumes/wireguard-gateway
    $ chmod 600 -R /etc/private-lan/volumes/wireguard-gateway

# Setup routing and NAT

#### Place files in directories
```
$ mv /tmp/private-lan/docker/files/service/init.d/gateway.service /etc/init.d/
$ mv /tmp/private-lan/docker/files/service/systemd/gateway.service /etc/systemd/system/
$ chmod 644 /etc/init.d/gateway.service
$ chmod 644 /etc/systemd/system/gateway.service
```
#### Make the scripts executable
```
$ chmod +x /etc/init.d/gateway.service
$ chmod +x /etc/private-lan/files/set-route.sh
```
#### Enable as a new service
```
$ systemctl daemon-reload
$ systemctl enable gateway.service
```

#### **Edit kernel parameters to enable IP forwarding and enhance security:**  
Uncomment/paste in /etc/sysctl.conf:  
```yaml
#IP Forwarding
net.ipv4.ip_forward = 1
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

    $ sysctl -p /etc/sysctl.conf 

*More info about these settings:  
[IP Spoofing](http://tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.kernel.rpf.html)  
[ICMP broadcast requests](https://www.cloudflare.com/learning/ddos/smurf-ddos-attack/)  
[ICMP redirects](https://askubuntu.com/questions/118273/what-are-icmp-redirects-and-should-they-be-blocked)  
[Source packet routing](https://www.ccexpert.us/basic-security-services/disable-ip-source-routing.html)  
[SYN attacks](https://www.symantec.com/connect/articles/hardening-tcpip-stack-syn-attacks)*

# Start everything up

    $ cd /etc/private-lan/
    $ docker-compose up -d
    $ systemctl start gateway.service

#### Set the Pi-Hole web interface password

    $ docker exec -it pihole pihole -a -p

#### Client setup

You can now manually configure your server as network gateway and DNS server. \
However it's much more convenient to simply activate the DHCP server build into Pi-Hole.

# Optional

- ### [DHCP server](DHCP.md)
- ### [PiVPN](PiVPN.md)