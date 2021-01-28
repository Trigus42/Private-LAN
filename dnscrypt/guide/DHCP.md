#### DHCP config

Create a .conf file like ```/etc/private-lan/volumes/dnsmasq/dhcp.conf```.  
To configure your DHCP server refer to the [official documentaion](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html).

Just for orientation, here is how my config looks like:

```xml
dhcp-authoritative

## New devices default ##
dhcp-range=192.168.178.200,192.168.178.254,24h
# Gateway
dhcp-option-force=3,192.168.178.2
# DNS1 and DNS2
dhcp-option-force=6,192.168.178.2,192.168.178.2

## Known devices (static IP address) default ##
# Devices in the IP range .20 - 199 are assigned to tag 0
dhcp-range=set:0,192.168.178.20,192.168.178.199,24h
# Gateway for tag 0
dhcp-option-force=tag:0,3,192.168.178.1
# DNS1 and DNS2 for tag 0
dhcp-option-force=tag:0,6,192.168.178.2,192.168.178.2

## Settings for devices which were assigned the 'VPN' tag to ##
dhcp-option-force=tag:VPN,3,192.168.178.2
dhcp-option-force=tag:VPN,6,192.168.178.2,192.168.178.2

dhcp-leasefile=/etc/dnsmasq.d/dhcp.leases
#quiet-dhcp

domain=lan
dhcp-rapid-commit
```

Example for the static DHCP leases:

```xml
# /etc/private-lan/volumes/dnsmasq.d/static-leases.conf

dhcp-host=81:7d:22:a2:3e:7d,192.168.178.20,PC-VPN,set:VPN
dhcp-host=81:7d:22:a2:3e:7e,192.168.178.21,PC
```

#### Restart dnsmasq

    $ docker restart dnsmasq

#### Disable other DHCP servers

Most likely you have to disable the DHCP server of your router. How to do this depends on the router but while some may not allow you to configure a custom DNS server, there is almost always an option to turn off it's DHCP server.