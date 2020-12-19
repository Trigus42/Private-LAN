#!/bin/sh
echo "Starting dnscrypt-proxy, build date $(cat /build-date.txt)"

# Change the default route to the wireguard gateway
ip route replace default via $(dig +short wireguard-gateway)

# Start dnscrypt-proxy
/usr/bin/dnscrypt-proxy -config /config/dnscrypt-proxy.toml
