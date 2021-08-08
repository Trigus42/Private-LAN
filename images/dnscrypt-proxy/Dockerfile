FROM alpine:3.14

RUN apk update; \
    apk add --no-cache dnscrypt-proxy bind-tools; \
    # clean up
    rm -rf /var/cache/apk/* /tmp/*

# add entrypoint file
COPY entrypoint.sh /
RUN  chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# set build date
RUN date >/build-date.txt
