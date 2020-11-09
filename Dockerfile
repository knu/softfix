FROM alpine:latest

RUN apk --no-cache add git curl jq bash grep

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
