FROM alpine:3.14

RUN apk update; \
    apk add --no-cache bash ca-certificates bind-tools wget unbound

RUN chown -R unbound:unbound /usr/share/dnssec-root/; \
    chmod -R 744 /usr/share/dnssec-root/; \
    chown -R unbound:unbound /etc/unbound/; \
    chmod -R 744 /etc/unbound/; \
    wget https://www.internic.net/domain/named.root -O /etc/unbound/root.hints

EXPOSE 53/udp 53/tcp

ADD unbound.conf /etc/unbound/

ADD entrypoint.sh /
RUN chmod +x entrypoint.sh
ENTRYPOINT ["/bin/sh","-c","/entrypoint.sh"]

# set build date
RUN date >/build-date.txt