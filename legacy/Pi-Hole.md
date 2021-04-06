## Install Pi-Hole:  
> Our code is completely open, but piping to bash can be dangerous. For a safer install, review the code and then run the installer locally.

    curl -sSL https://install.pi-hole.net | bash 

For this guide it's irrelevant what you choose in the installer.

### **Configure the Interface:**  
In case you didn't already set up your interface during the Pi-Hole installation, paste and overwrite any existing configuration for eth0 in /etc/dhcpcd.conf:  
```yaml
interface eth0
static ip_address=<IP> ##The IP address you want your server to have
static routers=<IP> ##The IP address of your router
static domain_name_servers=127.0.0.1
```

#### DHCP config
**Turn off the DHCP server of your router first.**  

Create the file ```/etc/dnsmasq.d/dhcp.conf``` with the following content:
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
dhcp-range=192.168.178.20,192.168.178.254,24h

# Router
dhcp-option=3,192.168.178.1
# Pi-Hole
dhcp-option=6,192.168.178.2

# VPN
dhcp-option=tag:VPN,3,192.168.178.2

dhcp-leasefile=/etc/pihole/dhcp.leases
#quiet-dhcp

domain=lan
dhcp-rapid-commit
```

```
dhcp-host=81:7d:22:a2:3e:7d,192.168.178.10,PC-VPN,set:VPN
dhcp-host=81:7d:22:a2:3e:7e,192.168.178.11,PC
```
</details>
