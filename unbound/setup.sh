#!/bin/bash

seperator() {
    screen_size=$(stty size)
    printf -v rows '%d' "${screen_size%% *}"
    for ((i=1;i<=rows;i++)); do echo -n "-"; done
    echo ""
}

msg_rows() {
    screen_size=$(stty size)
    printf -v rows '%d' "${screen_size%% *}"
    echo -n "$(( rows / 2 ))"
}

msg_columns() {
    screen_size=$(stty size)
    printf -v columns '%d' "${screen_size##* }"
    echo -n "$(( columns / 2 ))"
}

# User must be root
printf "\\n"
if [[ ! "${EUID}" -eq 0 ]]; then
    printf "Script called with non-root privileges"
    exit 1
fi

if whiptail --defaultno --title "Update" --yesno "Is recommended to update your system first.\nDepending on how old of an image you are using, this can take a while.\n\nDo you want to update?" $(msg_rows) $(msg_columns); then
	printf "\nUpdating...\n"
    seperator
	apt-get update
	apt-get upgrade -y
    seperator
fi

if whiptail --title "Install" --yesno "This script will now install\n- Docker\n- Python3\n- Docker Compose\n- Wireguard\n\nDo you want to proceed?" $(msg_rows) $(msg_columns); then
    printf "\nInstalling Docker...\n"
    seperator
    # curl -fsSL https://get.docker.com | bash
    seperator

    printf "\nInstalling Python3 and Docker Compose...\n"
    seperator
    apt install -y python3-pip -y
    pip3 install docker-compose -y
    seperator

    printf "\nInstalling Wireguard...\n"
    # Check if the Wireguard module is loaded
    if ! lsmod | grep "wireguard" &> /dev/null; then

        # If it is installed but not loaded, load it on boot-up
        if $(modprobe wireguard); then
            "wireguard" >> /etc/modules
            update-initramfs -u

        elif whiptail --title "Wireguard kernel module" --yesno "The Wireguard kernel module is not installed.\nDo you want to try installing it?" $(msg_rows) $(msg_columns); then
            # Add "unstable" sources
            seperator
            echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
            wget -q -O - https://ftp-master.debian.org/keys/archive-key-$(lsb_release -sr).asc &> /dev/null | sudo apt-key add - 
            printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable
            apt update

            # Kernel headers package is named differently on the RPi
            if [ $(python -c "import platform; print 'raspberrypi' in platform.uname()") == "True" ]; then
                apt install raspberrypi-kernel-headers wireguard -y
            else
                apt install linux-headers-$(uname -r) wireguard -y
            fi

            seperator
        else
            exit 1
    fi
else
    exit 1
fi

printf "\nPreparing configs...\n"
mkdir -p /etc/private-lan/volumes/{dnscrypt-proxy,wireguard-gateway,etc-pihole,etc-dnsmasq.d}
chown -R root /etc/private-lan/volumes/wireguard-gateway
chmod 600 -R /etc/private-lan/volumes/wireguard-gateway
printf "Downloading docker/files...\n"
git clone --quiet https://github.com/Trigus42/Private-LAN /tmp/private-lan
mv /tmp/private-lan/docker/files/etc/* /etc/private-lan/
printf "Creating dnscrypt-proxy base config...\n"
wget -q https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/release/dnscrypt-proxy/example-dnscrypt-proxy.toml -O /etc/private-lan/volumes/dnscrypt-proxy/dnscrypt-proxy.toml
sed -i "s/listen_addresses = \['127\.0\.0\.1:53']/listen_addresses = ['127.0.0.1:5300', '[::1]:5300']/gm" /etc/private-lan/volumes/dnscrypt-proxy/dnscrypt-proxy.toml
