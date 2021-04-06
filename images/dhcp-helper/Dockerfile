FROM alpine:3.12

RUN apk -U upgrade; \
    apk add dhcp-helper; \
    # clean up
    rm -rf /var/cache/apk/* /tmp/*    

EXPOSE 67 67/udp
ENTRYPOINT ["dhcp-helper", "-n"]