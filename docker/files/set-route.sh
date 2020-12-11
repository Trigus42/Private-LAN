#!/bin/bash
container=$1
gateway_ip=$2

pid=$(sudo docker inspect -f '{{.State.Pid}}' $container)

mkdir -p /var/run/netns
ln -s /proc/$pid/ns/net /var/run/netns/$pid
ip netns exec $pid ip route del default
ip netns exec $pid ip route add default via $gateway_ip
