## General
The goal is to set up Pi-Hole to filter the DNS queries, DNSCrypt-Proxy or Unbound as DNS resolver, a VPN gateway (and a VPN server).  
I assume that all commands are executed as root and Raspberry Pi OS is used as operating system. Most other Debian distributions should be fine though with some minor changes.

You might have to change some names and addresses. Depending on your environment you may have to adjust:
- The name of your network interface (eth0)
- The subnet and IP of your network interface (192.168.178.0/24 and 192.168.178.2)

## Variants

- ### [Unbound](unbound/guide/main.md) [(Network diagram)](unbound/guide/diagram.md)

- ### [DNSCrypt](dnscrypt/guide/main.md) [(Network diagram)](dnscrypt/guide/diagram.md)

- ### [Legacy](legacy/main.md)
  I won't actively work on it anymore but keep it for anyone looking for a reference to maintain their existing setup.

## Issues etc.
- If you encounter any issues please checkout the [Known-Issues](https://github.com/Trigus42/Private-LAN/wiki/Known-Issues) page in the wiki before you open up a new issue.  
- If anything is unclear to you, please feel free to ask using 'Discussions'.  
