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

### **Activate DNSSEC:** 
If DNSSEC is activated in DNSCrypt-Proxy, you should activate it in dnsmasq too:

    echo "proxy-dnssec" > /etc/dnsmasq.d/dnscrypt.conf 

### **Configure DHCP and DNS:**  
**Turn off the DHCP server of your router first.**  
*[In the Pi-Hole web interface]*

- Settings &rightarrow; DHCP &rightarrow; DHCP server enabled :heavy_check_mark:  
  *If you set up a VPN Gateway:* 
- Settings &rightarrow; DHCP &rightarrow; Router (gateway) IP address: <IP of the RPi (eth0)> &rightarrow; Save  
  *If you installed DNSCrypt-Proxy:*
- Settings &rightarrow; DNS &rightarrow;  
&nbsp;&nbsp;&rightarrow; Disable all "Upstream DNS Servers"  
&nbsp;&nbsp;&rightarrow; Enable Custom 1 (IPv4); Fill in ```127.0.0.1#5300```  
&nbsp;&nbsp;&rightarrow; Enable Custom 3 (IPv6); Fill in ```::1#5300```  
  *If DNSSEC is activated in DNSCrypt-Proxy:*
- Settings &rightarrow; DNS &rightarrow; Use DNSSEC :heavy_check_mark: &rightarrow; Save
