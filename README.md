## General
The goal is to set up Pi-Hole as DNS and DHCP server, DNSCrypt-Proxy to encrypt the DNS requests, a VPN gateway and a VPN server.  
I assume that all commands are executed as root and Debian Buster or Bullseye are used as operating system.

You might have to change some names and addresses. Depending on your environment you may have to adjust:
- The name of your network interface (eth0)
- The subnet and IP of your network interface (192.168.0.0/24 and 192.168.0.2)

## Variants

- ### [Docker](docker/guide/main.md)
  - Easy scalability (you can run multiple instances on one host)
  - No need for Pi-Hole or DNSCrypt-Proxy to support for your system 
  - Should work on every system that supports Docker and Wireguard, iproute2 and iptables

- ### [Standard](bare-metal/guide/main.md)