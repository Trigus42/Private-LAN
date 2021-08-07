#!/bin/bash

# Get default interface with lowest metric
lan_if="$(ip route | awk 'FNR == 1 {print $(5)}')"
# Overwrite interface
# lan_if="eth0"

# Get environment variables
docker_if="br-$(docker network ls | grep private-lan_net | cut -d' ' -f1)"
docker_if_ip="$(ip -4 addr show "$docker_if" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
docker_if_subnet="$(ip -o -f inet addr show "$docker_if" | awk '/scope global/ {print $4}' | perl -ne 's/(?<=\d.)\d{1,3}(?=\/)/0/g; print;')"
lan_subnet="$(ip -o -f inet addr show "$lan_if" | awk '/scope global/ {print $4}' | perl -ne 's/(?<=\d.)\d{1,3}(?=\/)/0/g; print;')"
wireguard_gateway_ip="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wireguard-gw)"
wireguard_dns_ip="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wireguard-dns)"
unbound_ip="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' unbound)"
default_gateway="$(ip route show default dev "$lan_if" | awk '/default/ { print $3 }')"

# Default route in a new routing table via the VPN Gateway
ip route add default via "$wireguard_gateway_ip" table 200
# Use new table for all packets from eth0
ip rule add from all iif eth0 lookup 200
# Use main routing table first but only match if at least the first bit of an IP range in it is matching the destination IP. It won't match 0.0.0.0/0 ("default")
ip rule add from all lookup main suppress_prefixlength 0

# Uncomment if you want the host to use the VPN tunnel too
# Route all traffic trough the Wireguard tunnel except for the the "wireguard_gateway" container and the non VPN unbound traffic
# ip route add default via $default_gateway table 201
# ip rule add from $wireguard_gateway_ip lookup 201
# ip rule add from $unbound_ip lookup 201
# ip route replace default via $wireguard_gateway_ip

# Don't allow forwarding from eth0 to eth0 (bypassing the VPN gateway)
if ! eval "iptables -C FORWARD -i eth0 -o eth0 -j REJECT &> /dev/null"; then
    iptables -I FORWARD -i eth0 -o eth0 -j REJECT
fi
# Allow forwarding from eth0 trough the docker interface to the Wireguard gateway
if ! eval "iptables -C FORWARD -i eth0 -o $docker_if -d $wireguard_gateway_ip -j ACCEPT &> /dev/null"; then
    iptables -I FORWARD -i eth0 -o "$docker_if" -d "$wireguard_gateway_ip" -j ACCEPT
fi
# Replace the source IP of packets going out trough the docker interface to the Wireguard container
if ! eval "iptables -t nat -C POSTROUTING ! -s $docker_if_subnet -d $wireguard_gateway_ip -o $docker_if -j MASQUERADE &> /dev/null"; then
    iptables -t nat -I POSTROUTING ! -s "$docker_if_subnet" -d "$wireguard_gateway_ip" -o "$docker_if" -j MASQUERADE
fi

# Wait until the pihole and pihole-vpn container finished start up
until eval "/usr/bin/docker inspect -f {{.State.Running}} pihole" && eval "/usr/bin/docker inspect -f {{.State.Running}} pihole-vpn"; do
    sleep 0.1;
done;

# Set the default route of the containers to the "wireguard-gw" container and add an exception for packets addressed to the LAN or Wireguard clients
bash /etc/private-lan/set-route.sh pihole-vpn "$wireguard_gateway_ip" "$docker_if_ip" "$lan_subnet" 10.6.0.0/24
bash /etc/private-lan/set-route.sh unbound-vpn "$wireguard_gateway_ip" "$docker_if_ip" "$lan_subnet" 10.6.0.0/24
# Reconfigure the routing table each time one of the containers are restarted 
docker events --filter "container=pihole-vpn" | awk '/container start/ { system("/etc/private-lan/set-route.sh pihole-vpn '"$wireguard_gateway_ip"' '"$docker_if_ip"' '"$lan_subnet"' 10.6.0.0/24") }' &
docker events --filter "container=unbound-vpn" | awk '/container start/ { system("/etc/private-lan/set-route.sh unbound-vpn '"$wireguard_gateway_ip"' '"$docker_if_ip"' '"$lan_subnet"' 10.6.0.0/24") }' &

# Set the default route of the containers to the "wireguard-dns" container and add an exception for packets addressed to the LAN or Wireguard clients
bash /etc/private-lan/set-route.sh pihole "$wireguard_dns_ip" "$docker_if_ip" "$lan_subnet" 10.6.0.0/24
bash /etc/private-lan/set-route.sh unbound "$wireguard_dns_ip" "$docker_if_ip" "$lan_subnet" 10.6.0.0/24
# Reconfigure the routing table each time one of the containers are restarted
docker events --filter "container=pihole" | awk '/container start/ { system("/etc/private-lan/set-route.sh unbound '"$wireguard_dns_ip"' '"$docker_if_ip"' '"$lan_subnet"' 10.6.0.0/24") }' &
docker events --filter "container=unbound" | awk '/container start/ { system("/etc/private-lan/set-route.sh unbound '"$wireguard_dns_ip"' '"$docker_if_ip"' '"$lan_subnet"' 10.6.0.0/24") }' &