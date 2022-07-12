ARG BUILD_FROM
FROM $BUILD_FROM

# Setup base
RUN apk add --no-cache nginx openssl autossh

# Copy data
COPY data/run.sh /
COPY data/nginx.conf /etc/
COPY data/tunnel.sh /

CMD [ "/run.sh" ]
