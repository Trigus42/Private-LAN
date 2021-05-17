#### Update all containers:

    $ docker-compose -f /etc/private-lan/docker-compose.yml pull
    $ docker-compose -f /etc/private-lan/docker-compose.yml build --no-cache
    $ docker-compose -f /etc/private-lan/docker-compose.yml up -d
    $ systemctl restart gateway