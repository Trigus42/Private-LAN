## Install DNSCrypt-Proxy:   

### **Download and extract DNSCrypt-Proxy:**  
Newest release: https://github.com/jedisct1/dnscrypt-proxy/releases/  
For the RPi you need the "linux-arm" version. Otherwise you probably need "linux_x86_64".
```xml
cd /etc
wget <Download Link>
tar -xf dnscrypt-proxy-linux_*-*.tar.gz
mv linux-arm dnscrypt-proxy
rm dnscrypt-proxy-linux_*-*.tar.gz
```

### **Configure DNSCrypt-Proxy:**  
```
cd /etc/dnscrypt-proxy
cp example-dnscrypt-proxy.toml dnscrypt-proxy.toml
```
Change in dnscrypt-proxy.toml:
```yaml
## Pi-Hole already uses Port 53
listen_addresses = ['127.0.0.1:5300', '[::1]:5300'] 
## Pi-Hole is our system resolver, which uses DNSCrypt-Proxy itself
ignore_system_dns = true
```
<details>
<summary>Some optional settings</summary>

```xml
server_names = [’ <SERVER NAME1>’, ’ <SERVER NAME2>’] ## If you want to use specific servers
ipv6_servers = false ## “true” if your VPN service supports IPv6
require_dnssec = true # I would recommend it for security reasons
require_nolog = true ## I would recommend it for privacy reasons
fallback_resolver = ‘176.126.70.119:53’ ## OpenNIC; You can use any server you trust

##Insert below “[sources]”:
[sources.’<LIST NAME>’]
urls = [’<List URL>’, ‘<BACKUP URL>’]
minisign_key = ‘<MINISIGN_KEY>’
cache_file = ‘<CACHE FILE (CUSTOM)>’

##Insert below “[anonymized_dns]”:
routes = [
{ server_name=’ <SERVER NAME1>’, via=[’ <RELAY NAME>’,<…>] },
{ server_name=’<SERVER NAME2>’, via=[’ <RELAY NAME>’,<…>] }
]
```
[Server/Relay lists ("Sources")](https://github.com/DNSCrypt/dnscrypt-resolvers/tree/master/v3)  
[More info about the servers](https://github.com/dyne/dnscrypt-proxy/blob/master/dnscrypt-resolvers.csv)
</details>

### **Install the service:**  
    ./dnscrypt-proxy -service install

### **Check your configuration:**  
    ./dnscrypt-proxy -resolve google.com
The output should look something like this:
```
Resolving [google.com]
Domain exists:  yes, 4 name servers found
Canonical name: google.com.
IP addresses:   172.217.23.110, 2a00:1450:4001:800::200e
TXT records:    v=spf1 include:_spf.google.com ~all facebook-domain-verification=22rm551cu4k0ab0bxsw536tlds4h95 docusign=1b0a6754-49b1-4db5-8540-d2c12664b289 globalsign-smime-dv=CDYX+XFHUw2wml6/Gb8+59BsH31KzUr6c1l2BPvqKX8= docusign=05958488-4752-4ef2-95eb-aa7ba8a3bd0e
Resolver IP:    45.87.212.50
```

### **Allow the service to bind to the specified port as non-root user:**  
    setcap cap_net_bind_service=+pe dnscrypt-proxy 

### **Start the service on boot:**  
    systemctl enable dnscrypt-proxy