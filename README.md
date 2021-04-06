## General
The goal is to set up Pi-Hole to filter the DNS queries, DNSCrypt-Proxy or Unbound as DNS resolver, a VPN gateway (and a VPN server).  
I assume that all commands are executed as root and Raspberry Pi OS is used as operating system. Most other Debian distributions should be fine though with some minor changes.

You might have to change some names and addresses. Depending on your environment you may have to adjust:
- The name of your network interface (eth0)
- The subnet and IP of your network interface (192.168.178.0/24 and 192.168.178.2)

If anything is unclear to you, please feel free to ask using 'Discussions'.

## Variants

- ### [Unbound](unbound/guide/main.md)

- ### [DNSCrypt](dnscrypt/guide/main.md)

- ### [Legacy](legacy/main.md)
  I won't actively work on it anymore but keep it for anyone looking for a reference to maintain their existing setup.

## Tags
I will create a new tag with a incremented major version number when making changes that could break existing setups.
