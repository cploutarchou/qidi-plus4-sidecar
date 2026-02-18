#!/bin/sh
set -e

# Substitute environment variables in nginx config
envsubst '${PRINTER_IP}${HOST_IP}' < /etc/nginx/conf.d/default.conf > /tmp/default.conf.tmp
mv /tmp/default.conf.tmp /etc/nginx/conf.d/default.conf

# Substitute environment variables in mainsail config
sed -i "s|192.168.68.26|${HOST_IP}|g" /usr/share/nginx/html/config.json

# Start nginx
nginx -g 'daemon off;'
