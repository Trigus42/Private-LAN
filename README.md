# Private-LAN
As the description says: The "setup.sh" script sets up an OpenVPN gateway, a DNS-Crypt server, and Pi-Hole on your Rapberry.
For more advanced configuration visit: https://discourse.pi-hole.net/t/openvpn-gateway-with-pihole-and-dnscrypt/26367

The "gateway_keepalive.sh" script is meant to restore all services in case of an error. Although the OpenVPN connection should reestablish after a disconnect and the DNS servers in principle should always work as long as there is a connection, you can never know and maybe you are not always around being able to investigate eventual problems.
It creates a basic log at "/var/log/gateway_log" whereas you could also redirect the output to a file to get some more precise insight. If for longer than 10 minutes it doesn't execute successfully, it reboots the machine, but you can easily change the time in the script or comment out the reboot command if it doesn't work for your configuration.

## Example
### Create a cronjob:
*Checks every minute and discards the raw output*
```
*/1 * * * * /bin/bash /etc/gateway_keepalive.sh > /dev/null 2>&1
```
*Checks every minute and redirects the output to /var/log/gateway_log_raw*
```
*/1 * * * * /bin/bash /etc/gateway_keepalive.sh > /var/log/gateway_log_raw
```
