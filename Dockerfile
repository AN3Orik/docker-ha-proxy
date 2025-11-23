FROM haproxy:3.2-alpine

USER root

RUN apk add --no-cache bash

RUN mkdir -p /var/log/haproxy

COPY generate-config.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/generate-config.sh

CMD ["/usr/local/bin/generate-config.sh"]