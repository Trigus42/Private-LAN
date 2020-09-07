### **Install PiVPN:**  
    curl -L https://install.pivpn.io | bash
 - Choose Wireguard as VPN type
 - If you got a changing public IP use a [DynDNS](https://wiki.archlinux.org/index.php/Dynamic_DNS) provider
 - Don't change your interface config from what you configured before (/etc/dhcpcd.conf).

### **Configure Routes:**  

*This seems like a duct tape solution to me. If you know a better/cleaner way of achieving this please let me know by opening an issue.*

Because your server also is a Wireguard client the request goes into eth0 but the response is sent over the Wireguard tunnel (wg0) and is reaching the client with a different IP. Also you probably want the clients to be able to access the local network.

Insert in /etc/wireguard/wg0.conf below `[Interface]`:

    PostUp = ip route add from <Your IP - as configured in /etc/dhcpcd.conf> lookup main && ip route add from 10.6.0.0/24 lookup main
    PostDown = ip route delete from <Your IP - as configured in /etc/dhcpcd.conf> lookup main && ip route delete from 10.6.0.0/24 lookup main

### **Add clients:**  

Now you can just add clients by using `pivpn add`.