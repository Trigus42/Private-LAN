FROM alpine:3.14

RUN apk update; \
    apk add --no-cache dnsmasq

ENTRYPOINT ["/usr/sbin/dnsmasq", "-k"]

# set build date
RUN date >/build-date.txt