FROM alpine:latest

RUN apk update && apk add --no-cache iptables iproute2

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]