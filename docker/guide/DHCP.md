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

#### Disable other DHCP servers

Most likely you have to disable the DHCP server of your router. How to do this depends on the router but while some may not allow to configure as custom DNS server, there is almost always an option to turn off it's DHCP server.