# Private-LAN
This Repo contains guides and scripts for setting up various services on your Debian server (e.g. a RPi) aiming on creating an all around solution for your home network.

## General
The goal is to set up Pi-Hole as DNS and DHCP server, DNSCrypt-Proxy to encrypt the DNS requests, a VPN gateway and a VPN server.  
I assume that all commands are executed as root, Raspbian Buster or Bullseye is used as operating system and your network interface is named "eth0". If you wan't to use you WiFi network card or another Ethernet interface just replace "eth0" by it's name everywhere.

If you encounter any problems feel free to open up an issue.

## Guide
Even if you don't wan't to use all services I would recommend setting up those you do want to in the following order.  

- ### DNSCrypt-Proxy
  Must be set up before configuring Pi-Hole to use localhost:5300 as DNS.

- ### VPN Gateway
  Must be set up before configuring the Pi-Hole DHCP to advertise your server as network gateway.

- ### Pi-Hole

- ### PiVPN

- ### Advanced
  - Leak testing
  - Automated security updates
  - Exclude devices from VPN Gateway/Pi-Hole
  - Simple Firewall
  - Per devices rules and timed rules
  

## setup.sh
The script is supposed to automate the basic setup process. However I don't actively work on it and wouldn't recommend using it yet.  
