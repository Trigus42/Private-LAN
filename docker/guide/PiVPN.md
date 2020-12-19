### **Install PiVPN:**  
    curl -L https://install.pivpn.io | bash
 - Choose Wireguard as VPN type
 - If you got a changing public IP use a [DynDNS](https://wiki.archlinux.org/index.php/Dynamic_DNS) provider like [dynv6](https://dynv6.com/)
 - Don't change your interface config from what you configured before (/etc/dhcpcd.conf)

### **Adjust routes:**
In ```/etc/init.d/gateway.service``` uncomment:

    ip route add 10.6.0.0/24 via 10.6.0.1 table 200

Reboot or execute the command above yourself.

### **Add clients:**  

Now you can add clients by using `pivpn add`.

### **Additional Step for Windows Clients:**

If you use WireGuard for Windows you may not be able to access your LAN right away.  
In that case you first need to add a route to your LAN via the tunnel:

Execute as admin in the Windows Command Prompt:

    route ADD <YOUR LAN> MASK <YOUR LANS SUBNET MASK> <THE WIREGAURD INTERFACE IP OF YOUR WG SERVER>
    
e.g.:
    
    route ADD 192.168.0.0 MASK 255.255.255.0 10.6.0.1
