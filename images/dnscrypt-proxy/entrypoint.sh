#!/bin/sh
echo "Starting dnscrypt-proxy, build date $(cat /build-date.txt)"

# Start dnscrypt-proxy
/usr/bin/dnscrypt-proxy -config /config/dnscrypt-proxy.toml
