FROM alpine:3.14

RUN apk update; \
    apk add --no-cache dhcp-helper; \
    # clean up
    rm -rf /var/cache/apk/* /tmp/*    

EXPOSE 67 67/udp
ENTRYPOINT ["dhcp-helper", "-n"]