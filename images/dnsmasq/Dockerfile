FROM alpine:3.12

RUN apk -U upgrade; \
    apk add --no-cache dnsmasq

ENTRYPOINT ["/usr/sbin/dnsmasq", "-k"]

# set build date
RUN date >/build-date.txt