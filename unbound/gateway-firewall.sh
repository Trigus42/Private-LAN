#!/bin/bash

# Get default interface with lowest metric
lan_if="$(ip route | awk 'FNR == 1 {print $(5)}')"
lan_subnet="$(ip -o -f inet addr show "$lan_if" | awk '/scope global/ {print $4}' | perl -ne 's/(?<=\d.)\d{1,3}(?=\/)/0/g; print;')"

# Don't allow forwarding from lan_if to lan_if (bypassing the VPN gateway)
iptables -I FORWARD -i "$lan_if" -o "$lan_if" -j REJECT

# Only allow VPN containers to directly access the internet
iptables -I FORWARD -s 172.16.238.0/24 ! -d "$lan_subnet" -o "$lan_if" -j REJECT
iptables -I FORWARD -s 172.16.238.2 -o "$lan_if" -j ACCEPT
iptables -I FORWARD -s 172.16.238.8 -o "$lan_if" -j ACCEPT