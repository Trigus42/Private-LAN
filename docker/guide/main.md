# Setup Docker

#### Install Docker Engine:

    $ curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    $ sh /tmp/get-docker.sh

#### Install Docker Compose:

    $ apt install python3-pip -y && pip3 install docker-compose

#### Enable Docker to start on boot:

    $ systemctl enable docker


# Install Wireguard
 If you want to use Wireguard on **Buster** or lower, you have to install the kernel module first.

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

# Prepare the volumes

#### Create the volume folders:

    $ mkdir -p /etc/private-lan/volumes
    $ cd /etc/private-lan/volumes
    $ mkdir dnscrypt-proxy wireguard-gateway etc-pihole etc-dnsmasq.d

#### Get config files:

    $ git clone https://github.com/Trigus42/Private-LAN /tmp/private-lan
    $ mv /tmp/private-lan/docker/files /etc/private-lan/

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

#### Assign permissions and ownership

    $ chown -R root /etc/private-lan/volumes/wireguard-gateway
    $ chmod 600 -R /etc/private-lan/volumes/wireguard-gateway


# Setup your containers

#### Create the compose file:

Create the file ```/etc/private-lan/docker-compose.yml``` with the following content:

```dockerfile
version: "3.8"

services:
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    networks:
      net:
        ipv4_address: 172.16.238.3
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
      - "443:443/tcp"
    environment:
      #Replace with your time Zone
      TZ: 'Europe/London' 
      DNS1: '172.16.238.4#5300'
      DNS2: 'no'
      #If you enabled it in dnscrypt-proxy
      DNSSEC: 'true'
      DNSMASQ_LISTENING: 'all'
    volumes:
      - '/etc/private-lan/volumes/etc-pihole/:/etc/pihole/'
      - '/etc/private-lan/volumes/etc-dnsmasq.d/:/etc/dnsmasq.d/'
    cap_add:
      - NET_ADMIN
      - SYS_NICE
    restart: always
    depends_on:
      - dnscrypt-proxy
      - dhcp-helper

  dnscrypt-proxy:
    build: files/dnscrypt-proxy
    container_name: dnscrypt-proxy
    networks:
      net:
        ipv4_address: 172.16.238.4
    expose:
      - "5300/udp"
      - "5300/tcp"
    volumes:
      - '/etc/private-lan/volumes/dnscrypt-proxy/:/config/'
    restart: always
    #To change the default route to the wireguard container
    cap_add:
      - NET_ADMIN
    depends_on:
      - wireguard

  dhcp-helper:
    build: files/dhcp-helper
    container_name: dhcp-helper
    restart: always
    network_mode: "host"
    command: -s 172.16.238.3
    cap_add:
      - NET_ADMIN

  wireguard:
    image: linuxserver/wireguard
    container_name: wireguard-gateway
    volumes:
    - '/etc/private-lan/volumes/wireguard-gateway/:/config'
    networks:
      net:
        ipv4_address: 172.16.238.2
        ipv6_address: 2001:3984:3989::2
    restart: always
    privileged: true
    cap_add:
    - NET_ADMIN
    - SYS_MODULE

networks:
  net:
    driver: bridge
    driver_opts:
      com.docker.network.enable_ipv6: "true"
    ipam:
      driver: default
      config:
      - subnet: 172.16.238.0/24
        gateway: 172.16.238.1
      - subnet: 2001:3984:3989::/64
        gateway: 2001:3984:3989::1
```

# Setup routing and NAT

Create the file /etc/init.d/gateway.service with the following content: 
```
#!/bin/bash

# Name of the interface that connects to your LAN (usually eth0)
lan_if="eth0"

# Get environment variables
docker_if="br-$(docker network ls | grep net | cut -d' ' -f1)"
docker_if_ip="$(ip -4 addr show $docker_if | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
docker_if_subnet="$(ip -o -f inet addr show $docker_if | awk '/scope global/ {print $4}' | perl -ne 's/(?<=\d.)\d{1,3}(?=\/)/0/g; print;')"
lan_subnet="$(ip -o -f inet addr show $lan_if | awk '/scope global/ {print $4}' | perl -ne 's/(?<=\d.)\d{1,3}(?=\/)/0/g; print;')"
wireguard_gateway_ip="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wireguard-gateway)"
default_gateway="$(ip route show default dev $lan_if | awk '/default/ { print $3 }')"

# Default route in a new table via the VPN Gateway
ip route add default via $wireguard_gateway_ip table 200
# Exception to the default route: Route requests for the Docker network via the docker interface
ip route add $docker_if_subnet via $docker_if_ip table 200
# Use new routing table for all request coming into the LAN interface
ip rule add iif eth0 lookup 200

# Uncomment if you want the host to use the VPN tunnel too
# Route all traffic trough the Wireguard tunnel except for the the "wireguard_gateway" container traffic
# ip route add default via $default_gateway table 201
# ip rule add from $wireguard_gateway_ip lookup 201
# ip route replace default via $wireguard_gateway_ip

# Uncomment if you want to use PiVPN
# Exception to the default route: Route packets for the Wireguard clients (responses to requests) via the Wireguard interface
# ip route add 10.6.0.0/24 via 10.6.0.1 table 200

# Don't allow forwarding from eth0 to eth0 (bypassing the VPN gateway)
iptables -I FORWARD -i eth0 -o eth0 -j REJECT
# Allow forwarding from eth0 trough the docker interface to the Wireguard gateway
iptables -I FORWARD -i eth0 -o $docker_if -d $wireguard_gateway_ip -j ACCEPT

# Replace the source IP of packets going out trough the docker interface to the Wireguard container
iptables -t nat -I POSTROUTING ! -s $docker_if_subnet -d $wireguard_gateway_ip -o $docker_if -j MASQUERADE

# Wait until the pihole container finished start up
until [ "`/usr/bin/docker inspect -f {{.State.Running}} pihole`"=="true" ]; do
    sleep 0.1;
done;

# Set the default route of the "pihole" container to the "wireguard_gateway" container and add an exception for packets addressed to the LAN or Wireguard clients
bash /etc/private-lan/files/set-route.sh pihole $wireguard_gateway_ip $docker_if_ip $lan_subnet 10.6.0.0/24

# Reconfigure the routing table each time the container "pihole" is restarted 
docker events --filter "container=pihole" | awk '/container start/ { system("/etc/private-lan/files/set-route.sh pihole '$wireguard_gateway_ip' '$docker_if_ip' '$lan_subnet' 10.6.0.0/24") }'
```

    $ chmod +x /etc/init.d/gateway.service
    $ chmod +x /etc/private-lan/files/set-route.sh

Create the file /etc/systemd/system/gateway.service with the following content:
```
[Unit]
Description=adding routes and rules to enable the Docker Wireguard gateway
After=docker.service

[Service]
ExecStart=/etc/init.d/gateway.service

[Install]
WantedBy=default.target
```
```
$ chmod 644 /etc/systemd/system/gateway.service
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

# Configure DHCP

#### Static Interface configuration:
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

#### DHCP config

Create the file ```/etc/private-lan/volumes/etc-dnsmasq.d/dhcp.conf``` with the following content:
```xml
dhcp-authoritative
domain=lan
dhcp-rapid-commit

dhcp-range=<Start>,<End>,24h

# Default Gateway (VPN or your Router)
dhcp-option=3,<Gateway>
# Default DNS
dhcp-option=6,<DNS>

# Tag for assigning individual devices to other Gateway
dhcp-option=tag:<tag>,3,<Gateway>

dhcp-leasefile=/etc/pihole/dhcp.leases
```

Now you can assign individual devices by adding them in /etc/private-lan/volumes/etc-dnsmasq.d/static-leases.conf:

```xml
dhcp-host=<MAC address>,<IP address>,<NAME>,set:<tag>
```
<details>
<summary>Example</summary>

```xml
dhcp-authoritative
dhcp-range=192.168.0.20,192.168.0.254,24h

# Router
dhcp-option=3,192.168.0.1
# Pi-Hole
dhcp-option=6,192.168.0.2

# VPN
dhcp-option=tag:VPN,3,192.168.0.2

dhcp-leasefile=/etc/pihole/dhcp.leases
#quiet-dhcp

domain=lan
dhcp-rapid-commit
```

```
dhcp-host=81:7d:22:a2:3e:7d,192.168.0.10,PC-VPN,set:VPN
dhcp-host=81:7d:22:a2:3e:7e,192.168.0.11,PC
```
</details>

#### Restart Pi-Hole

    $ docker restart pihole

# Optional

- ### [PiVPN](PiVPN.md)