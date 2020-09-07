# Private-LAN
This Repo contains guides and scripts for setting up various services on your Debian server (e.g. a RPi) aiming on creating an all around solution to protect your privacy.  

## Guide
Even if you don't wan't to use all services I would recommend setting up those you do want to in the following order.  

- ### DNSCrypt-Proxy
  Must be set up before configuring Pi-Hole to use localhost:5300 as DNS.

- ### VPN Gateway
  Must be set up before configuring the Pi-Hole DHCP to advertise your server as network gateway.

- ### Pi-Hole

- ### PiVPN

- ### Optional settings
  Addional config advise and testing

## setup.sh
The script is supposed to automate the basic setup process. However I don't actively work on it and wouldn't recommend using it yet.  
