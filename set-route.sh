#!/bin/bash
container=$1
new_gateway=$2

pid="$(docker inspect -f '{{.State.Pid}}' "$container")"
mkdir -p /var/run/netns
ln -s /proc/"$pid"/ns/net /var/run/netns/"$pid"

# Replace old gateway
ip netns exec "$pid" ip route del default
ip netns exec "$pid" ip route add default via "$new_gateway"

# Optionally set up an alternative gateway for certain IP ranges
if (($# > 3)); then 
   alternative_gateway=$3
   for ((i=4;i<=$#;i++)); do
   ip netns exec "$pid" ip route add "${!i}" via "$alternative_gateway"
   done
fi