#!/bin/bash

finished () 
{
    printf "\n" >> /var/log/gateway_log
    rm /tmp/gateway_keepalive.lock
    if $1; then exit 0; else finished false; fi
}

connection_test ()
{
    timeout 2 bash -c "</dev/tcp/$1" && echo true || echo false
}

#Retry after 5 min in case the script had been interrupted
if [ ! -f /tmp/gateway_keepalive.lock ] || (( ($(date +%s) - $(< /tmp/gateway_keepalive.lock)) > 300 )) ; then
    echo $(date +"%s") > /tmp/gateway_keepalive.lock
    if (( ! ping google.com -c 1 ) && ( ! ping pool.ntp.org -c 1 )); then
        echo "$(date +"%x %X") Request failure (google.com & pool.ntp.org)" >> /var/log/gateway_log
        if ! $(connection_test 1.1.1.1/53) && ! $(connection_test 8.8.8.8/53); then
            echo "$(date +"%x %X") No internet connection (1.1.1.1 & 8.8.8.8)" >> /var/log/gateway_log
            echo "$(date +"%x %X") Stopping OpenVPN" >> /var/log/gateway_log
            /usr/sbin/service openvpn stop

            if ! $(connection_test 1.1.1.1/53) && ! $(connection_test 8.8.8.8/53); then
                echo "$(date +"%x %X") No internet connection (1.1.1.1 & 8.8.8.8)" >> /var/log/gateway_log 
                iptables_backup_file="/etc/iptables/backups/backup_$(date +"%C.%m.%d-%X").v4"
                echo "$(date +"%x %X") Restoring ip-tables (Backup of current rules at $iptables_backup_file" >> /var/log/gateway_log
                if [ ! -e /etc/iptables/backups/ ]; then mkdir /etc/iptables/backups/; fi
                /usr/sbin/iptables-save > "$iptables_backup_file"
                /usr/sbin/iptables-restore /etc/iptables/rules.v4
            fi

            if ! dig google.com -p 5300 && ! dig ntp.org -p 5300; then
                echo "$(date +"%x %X") DNSCrypt-Proxy failure (google.com & pool.ntp.org)" >> /var/log/gateway_log
                echo "$(date +"%x %X") Restarting DNSCrypt-Proxy" >> /var/log/gateway_log
                /usr/sbin/service dnscrypt-proxy restart
                if ! dig google.com -p 5300 && ! dig ntp.org -p 5300; then
                    echo "$(date +"%x %X") DNSCrypt-Proxy not functional (google.com & ntp.org)" >> /var/log/gateway_log
                    finished false
                elif ! dig google.com && ! dig ntp.org; then
                    echo "$(date +"%x %X") DNSCrypt-Proxy working (google.com & ntp.org)" >> /var/log/gateway_log
                    echo "$(date +"%x %X") DNS (PiHole) failure (google.com & ntp.org)" >> /var/log/gateway_log
                    echo "$(date +"%x %X") Restarting PiHole-FTL" >> /var/log/gateway_log
                    /usr/sbin/service pihole-FTL restart
                    if ! dig google.com && ! dig ntp.org; then
                        echo "$(date +"%x %X") DNS (PiHole) not functional (google.com & ntp.org)" >> /var/log/gateway_log
                        finished false
                    fi
                fi

            elif ! dig google.com && ! dig ntp.org; then
                echo "$(date +"%x %X") DNSCrypt-Proxy working (google.com & ntp.org)" >> /var/log/gateway_log
                echo "$(date +"%x %X") DNS (PiHole) failure (google.com & ntp.org)" >> /var/log/gateway_log
                echo "$(date +"%x %X") Restarting PiHole-FTL" >> /var/log/gateway_log
                /usr/sbin/service pihole-FTL restart
                if ! dig google.com && ! dig ntp.org; then
                    echo "$(date +"%x %X") DNS (PiHole) not functional (google.com & ntp.org)" >> /var/log/gateway_log
                    finished false
                fi
            fi
            echo "$(date +"%x %X") (Re)starting OpenVPN" >> /var/log/gateway_log
            ovpn_restart = true
            /usr/sbin/service openvpn restart


        elif ! dig google.com && ! dig ntp.org; then
            echo "$(date +"%x %X") DNS failure (google.com & pool.ntp.org)" >> /var/log/gateway_log
            if ! dig google.com -p 5300 && ! dig ntp.org -p 5300; then
                echo "$(date +"%x %X") DNSCrypt-Proxy failure (google.com & pool.ntp.org)" >> /var/log/gateway_log
                echo "$(date +"%x %X") Restarting DNSCrypt-Proxy" >> /var/log/gateway_log
                /usr/sbin/service dnscrypt-proxy restart
                if ! dig google.com -p 5300 && ! dig ntp.org -p 5300; then
                    echo "$(date +"%x %X") DNSCrypt-Proxy not functional (google.com & ntp.org)" >> /var/log/gateway_log
                    finished false
                elif ! dig google.com && ! dig ntp.org; then
                    echo "$(date +"%x %X") DNSCrypt-Proxy working (google.com & ntp.org)" >> /var/log/gateway_log
                    echo "$(date +"%x %X") DNS (PiHole) failure (google.com & ntp.org)" >> /var/log/gateway_log
                    echo "$(date +"%x %X") Restarting PiHole-FTL" >> /var/log/gateway_log
                    /usr/sbin/service pihole-FTL restart
                    if ! dig google.com && ! dig ntp.org; then
                        echo "$(date +"%x %X") DNS (PiHole) not functional (google.com & ntp.org)" >> /var/log/gateway_log
                        finished false
                    fi
                fi

            elif ! dig google.com && ! dig ntp.org; then
                echo "$(date +"%x %X") DNSCrypt-Proxy working (google.com & ntp.org)" >> /var/log/gateway_log
                echo "$(date +"%x %X") DNS (PiHole) failure (google.com & ntp.org)" >> /var/log/gateway_log
                echo "$(date +"%x %X") Restarting PiHole-FTL" >> /var/log/gateway_log
                /usr/sbin/service pihole-FTL restart
                if ! dig google.com && ! dig ntp.org; then
                    echo "$(date +"%x %X") DNS (PiHole) not functional (google.com & ntp.org)" >> /var/log/gateway_log
                    finished false
                fi
            fi
        fi
        if ping google.com -c 1 || ping pool.ntp.org -c 1; then
            echo "$(date +"%x %X") Success. Internet connection restored" >> /var/log/gateway_log
        else
            if [ ! -f /tmp/gateway_failure ]; then
                echo $(date +"%s") > /tmp/gateway_failure
                finished false
            else
                time_offline=($(date +"%s") - $(< /tmp/gateway_failure))
                #After 10 min offtime, reboot
                if ( $time_offline >  600 ); then
                    echo "$(date +"%x %X") More than 10 minutes since last succesfull execution. rebooting..." >> /var/log/gateway_log
                    printf "\n" >> /var/log/gateway_log
                    reboot
                fi
            fi
        fi
    fi
    if (( ! ping 1.1.1.1 -c 1 -I tun0 ) && ( ! ping 8.8.8.8 -c 1 -I tun0 )) && (( ping 1.1.1.1 -c 1 ) || ( ping 8.8.8.8 -c 1 )); then
        echo "$(date +"%x %X") Internet connection but OpenVPN failure" >> /var/log/gateway_log
        if ! ovpn_restart; then /usr/sbin/service openvpn restart; fi
        start=$(date +%s)
        while (( ($(date +%s) - $start) <= 30 ))
        do
            if (( ping 1.1.1.1 -c 1 -I tun0 ) || ( ping 8.8.8.8 -c 1 -I tun0 )); then
                echo "$(date +"%x %X") Success. OpenVPN connection restored" >> /var/log/gateway_log
                finished true
            fi
            /bin/sleep 0.5
        done
        echo "$(date +"%x %X") OpenVPN not working" >> /var/log/gateway_log
        finished false
    fi
    rm /tmp/gateway_keepalive.lock
fi
