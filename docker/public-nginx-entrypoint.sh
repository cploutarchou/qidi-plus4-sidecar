#!/bin/sh
set -eu

PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-_}"
HTTP_TEMPLATE="/etc/nginx/templates/public-http.conf.template"
TLS_TEMPLATE="/etc/nginx/templates/public-tls.conf.template"
TARGET_CONFIG="/etc/nginx/conf.d/default.conf"
CERT_PATH="/etc/letsencrypt/live/${PUBLIC_DOMAIN}/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/${PUBLIC_DOMAIN}/privkey.pem"

mkdir -p /etc/nginx/conf.d

render_template() {
    template_path="$1"
    sed "s|\${PUBLIC_DOMAIN}|${PUBLIC_DOMAIN}|g" "$template_path" > "$TARGET_CONFIG"
}

if [ -n "$PUBLIC_DOMAIN" ] && [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
    echo "[public-nginx] Found certificate for ${PUBLIC_DOMAIN}; enabling HTTPS" >&2
    render_template "$TLS_TEMPLATE"
else
    echo "[public-nginx] Certificate for ${PUBLIC_DOMAIN} not found yet; serving HTTP only" >&2
    render_template "$HTTP_TEMPLATE"
fi

exec nginx -g 'daemon off;'
