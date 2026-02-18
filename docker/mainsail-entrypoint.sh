#!/bin/sh
set -e

echo "=== Custom Entrypoint Started ===" >&2

# Set default values if not provided
PRINTER_IP="${PRINTER_IP:-192.168.68.35}"
HOST_IP="${HOST_IP:-192.168.68.26}"

echo "PRINTER_IP: ${PRINTER_IP}" >&2
echo "HOST_IP: ${HOST_IP}" >&2

# Create processed config directory
mkdir -p /etc/nginx/conf.d.processed

# Process nginx config from template using sed
# Handle both simple ${VAR} and bash-style ${VAR:-default} patterns
echo "Processing nginx config from template..." >&2
sed -e "s/\${PRINTER_IP:-[^}]*}/${PRINTER_IP}/g" \
    -e "s/\${PRINTER_IP}/${PRINTER_IP}/g" \
    -e "s/\${HOST_IP:-[^}]*}/${HOST_IP}/g" \
    -e "s/\${HOST_IP}/${HOST_IP}/g" \
    /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d.processed/default.conf

# Show debug info  
echo "Sample of processed configuration:" >&2
head -20 /etc/nginx/conf.d.processed/default.conf | grep -E "(server|proxy_set_header Host)" >&2

# Copy the processed config directly to the location nginx will load
echo "Copying processed config to /etc/nginx/conf.d/..." >&2
cat /etc/nginx/conf.d.processed/default.conf > /etc/nginx/conf.d/default.conf

echo "Starting nginx..." >&2
# Start nginx
exec nginx -g 'daemon off;'
