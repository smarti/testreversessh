#!/usr/bin/with-contenv bashio
set -e

DHPARAMS_PATH=/data/dhparams.pem

CLOUDFLARE_CONF=/data/cloudflare.conf

DOMAIN=$(bashio::config 'domain')
KEYFILE=$(bashio::config 'keyfile')
CERTFILE=$(bashio::config 'certfile')
HSTS=$(bashio::config 'hsts')

HA_PORT=$(bashio::core.port)

REMOTEPORT=$(bashio::config 'remote_port')
REMOTEUSER=$(bashio::config 'remote_user')
REMOTEADDRESS=$(bashio::config 'remote_address')

sed -i "s/%%REMOTEPORT%%/$REMOTEPORT/g" /data/tunnel.sh
sed -i "s/%%REMOTEUSER%%/$REMOTEUSER/g" /data/tunnel.sh
sed -i "s/%%REMOTEADDRESS%%/$REMOTEADDRESS/g" /data/tunnel.sh

# Generate dhparams
if ! bashio::fs.file_exists "${DHPARAMS_PATH}"; then
    bashio::log.info  "Generating dhparams (this will take some time)..."
    openssl dhparam -dsaparam -out "$DHPARAMS_PATH" 4096 > /dev/null
fi

if bashio::config.true 'cloudflare'; then
    sed -i "s|#include /data/cloudflare.conf;|include /data/cloudflare.conf;|" /etc/nginx.conf
    # Generate cloudflare.conf
    if ! bashio::fs.file_exists "${CLOUDFLARE_CONF}"; then
        bashio::log.info "Creating 'cloudflare.conf' for real visitor IP address..."
        echo "# Cloudflare IP addresses" > $CLOUDFLARE_CONF;
        echo "" >> $CLOUDFLARE_CONF;

        echo "# - IPv4" >> $CLOUDFLARE_CONF;
        for i in $(curl https://www.cloudflare.com/ips-v4); do
            echo "set_real_ip_from ${i};" >> $CLOUDFLARE_CONF;
        done

        echo "" >> $CLOUDFLARE_CONF;
        echo "# - IPv6" >> $CLOUDFLARE_CONF;
        for i in $(curl https://www.cloudflare.com/ips-v6); do
            echo "set_real_ip_from ${i};" >> $CLOUDFLARE_CONF;
        done

        echo "" >> $CLOUDFLARE_CONF;
        echo "real_ip_header CF-Connecting-IP;" >> $CLOUDFLARE_CONF;
    fi
fi

# Prepare config file
sed -i "s#%%FULLCHAIN%%#$CERTFILE#g" /etc/nginx.conf
sed -i "s#%%PRIVKEY%%#$KEYFILE#g" /etc/nginx.conf
sed -i "s/%%DOMAIN%%/$DOMAIN/g" /etc/nginx.conf
sed -i "s/%%HA_PORT%%/$HA_PORT/g" /etc/nginx.conf

[ -n "$HSTS" ] && HSTS="add_header Strict-Transport-Security \"$HSTS\" always;"
sed -i "s/%%HSTS%%/$HSTS/g" /etc/nginx.conf

# Allow customize configs from share
if bashio::config.true 'customize.active'; then
    CUSTOMIZE_DEFAULT=$(bashio::config 'customize.default')
    sed -i "s|#include /share/nginx_proxy_default.*|include /share/$CUSTOMIZE_DEFAULT;|" /etc/nginx.conf
    CUSTOMIZE_SERVERS=$(bashio::config 'customize.servers')
    sed -i "s|#include /share/nginx_proxy/.*|include /share/$CUSTOMIZE_SERVERS;|" /etc/nginx.conf
fi

tunnel.sh

# start server
bashio::log.info "Running nginx..."
exec nginx -c /etc/nginx.conf < /dev/null
