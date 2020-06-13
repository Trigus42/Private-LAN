#!/bin/bash
#Retry after 5 min in case the script had been interrupted
if [ ! -f /tmp/gateway_keepalive.lock ] || (( ($(date +%s) - $(< /tmp/gateway_keepalive.lock)) > 300 )) ; then
    echo $(date +"%s") > /tmp/gateway_keepalive.lock
    if (( ! ping google.com -c 1 ) && ( ! ping pool.ntp.org -c 1 )); then
        echo "$(date +"%x %X") Request failure (google.com & pool.ntp.org)" >> /var/log/gateway_log
        if ! echo -n >/dev/tcp/1.1.1.1/53 && ! echo -n >/dev/tcp/8.8.8.8/53; then
            /usr/sbin/service openvpn stop

            if ! echo -n >/dev/tcp/1.1.1.1/53 && ! echo -n >/dev/tcp/8.8.8.8/53; then
                echo "$(date +"%x %X") No internet connection (1.1.1.1 & 8.8.8.8)" >> /var/log/gateway_log 
                iptables_backup_file="/etc/iptables/backup_$(date +"%x%X").v4"
                echo "$(date +"%x %X") Restoring ip-tables (Backup of current rules at $iptables_backup_file" >> /var/log/gateway_log
                /usr/sbin/iptables-save > "$iptables_backup_file"
                /usr/sbin/iptables-restore /etc/iptables/rules.v4
                exit 1

            elif ! dig google.com -p 5300 && ! dig ntp.org -p 5300; then
                /usr/sbin/service dnscrypt-proxy restart
                if ! dig google.com -p 5300 && ! dig ntp.org -p 5300; then
                    echo "$(date +"%x %X") DNSCrypt-Proxy not working (google.com & ntp.org)" >> /var/log/gateway_log
                    exit 1
                elif ! dig google.com && ! dig ntp.org; then
                    /usr/sbin/service pihole-FTL restart
                    if ! dig google.com && ! dig ntp.org; then
                        echo "$(date +"%x %X") DNS (PiHole) not working (google.com & ntp.org)" >> /var/log/gateway_log
                        exit 1
                    fi
                fi

            elif ! dig google.com && ! dig ntp.org; then
                /usr/sbin/service pihole-FTL restart
                if ! dig google.com && ! dig ntp.org; then
                    echo "$(date +"%x %X") DNS (PiHole) not working (google.com & ntp.org)" >> /var/log/gateway_log
                    exit 1
                fi
            fi
            /usr/sbin/service openvpn restart


        elif ! dig google.com && ! dig ntp.org; then
            if ! dig google.com -p 5300 && ! dig ntp.org -p 5300; then
                /usr/sbin/service dnscrypt-proxy restart
                if ! dig google.com -p 5300 && ! dig ntp.org -p 5300; then
                    echo "$(date +"%x %X") DNSCrypt-Proxy not working (google.com & ntp.org)" >> /var/log/gateway_log
                    exit 1
                elif ! dig google.com && ! dig ntp.org; then
                    /usr/sbin/service pihole-FTL restart
                    if ! dig google.com && ! dig ntp.org; then
                        echo "$(date +"%x %X") DNS (PiHole) not working (google.com & ntp.org)" >> /var/log/gateway_log
                        exit 1
                    fi
                fi

            elif ! dig google.com && ! dig ntp.org; then
                /usr/sbin/service pihole-FTL restart
                if ! dig google.com && ! dig ntp.org; then
                    echo "$(date +"%x %X") DNS (PiHole) not working (google.com & ntp.org)" >> /var/log/gateway_log
                    exit 1
                fi
            fi
        fi

        if ping google.com -c 1 || ping pool.ntp.org -c 1; then
            echo "$(date +"%x %X") Success. Internet connection restored" >> /var/log/gateway_log
            rm /tmp/gateway_failure
        else
            if [ ! -f /tmp/gateway_failure ]; then
                echo $(date +"%x %X") > /tmp/gateway_failure
            else
                time_offline=($(date +"%x %X") - $(< /tmp/gateway_keepalive.lock))
                #After 10 min offtime, reboot
                if ( $time_offline >  600 ); then
                    echo "$(date +"%x %X") More than 10 minutes since last succesfull execution. rebooting..." >> /var/log/gateway_log
                    reboot
                fi
            fi
        fi
    fi

    if (( ! ping 1.1.1.1 -c 1 -I tun0 ) && ( ! ping 8.8.8.8 -c 1 -I tun0 )) && (( ping 1.1.1.1 -c 1 ) || ( ping 8.8.8.8 -c 1 )); then
        echo "$(date +"%x %X") Internet connection but OpenVPN failure" >> /var/log/gateway_log
        /usr/sbin/service openvpn restart
        start=$(date +%s)
        while (( ($(date +%s) - $start) <= 30 ))
        do
            if (( ping 1.1.1.1 -c 1 -I tun0 ) || ( ping 8.8.8.8 -c 1 -I tun0 )); then
                echo "$(date +"%x %X") Success. OpenVPN connection restored" >> /var/log/gateway_log
                exit 0
            fi
            /bin/sleep 0.5
        done
        echo "$(date +"%x %X") OpenVPN not working" >> /var/log/gateway_log
    fi
    rm /tmp/gateway_keepalive.lock
fi