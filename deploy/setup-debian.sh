#!/usr/bin/env bash
# Setup for serving ozzyhelix.xyz on a Debian LXC container inside Proxmox.
# Serves the site on the local NAT network via nginx (no Cloudflare yet).
#
# Usage:
#   bash setup-debian.sh                          # uses /opt/ozzyhelix-site -> /var/www/html
#   bash setup-debian.sh SRC_DIR                  # copy SRC_DIR into /var/www/html
#   bash setup-debian.sh SRC_DIR DEST_DIR         # copy SRC_DIR into DEST_DIR
#
# Examples:
#   bash setup-debian.sh                          # default source /opt/ozzyhelix-site
#   bash setup-debian.sh /opt/ozzyhelix-site /var/www/my-site
#
# Access the site afterwards at http://<container-ip>/

set -euo pipefail

SITE_SRC="${1:-/opt/ozzyhelix-site}"
SITE_DIR="${2:-/var/www/html}"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash setup-debian.sh" >&2
    exit 1
fi

echo "==> Installing nginx and PHP-FPM"
apt-get update
apt-get install -y nginx rsync php-fpm

PHP_SOCK="$(ls /run/php/*.sock 2>/dev/null | head -n1 || true)"
if [[ -z "$PHP_SOCK" ]]; then
    # Start the FPM pool that apt just installed (name it e.g. php8.2-fpm).
    PHP_UNIT="$(basename "$(ls /etc/init.d/php*-fpm 2>/dev/null | head -n1)")"
    if [[ -n "$PHP_UNIT" ]]; then
        systemctl enable --now "$PHP_UNIT" 2>/dev/null || true
        PHP_SOCK="$(ls /run/php/*.sock 2>/dev/null | head -n1 || true)"
    fi
fi
if [[ -z "$PHP_SOCK" ]]; then
    echo "NOTE: PHP-FPM socket not found yet; the counter will come up once php8.2-fpm starts on boot." >&2
fi
# nginx -t needs a concrete socket; fall back to the standard Debian path.
PHP_SOCK="${PHP_SOCK:-/run/php/php8.2-fpm.sock}"
echo "==> Using PHP-FPM socket: $PHP_SOCK"

echo "==> Copying the site"
mkdir -p "$SITE_DIR"
if [[ -d "$SITE_SRC" ]]; then
    rsync -a "$SITE_SRC"/ "$SITE_DIR"/
    chown -R www-data:www-data "$SITE_DIR"
else
    echo "WARNING: site source $SITE_SRC not found. Drop your files into $SITE_DIR manually."
fi
# Make sure the counter has a place to store its count after redeploys
mkdir -p "$SITE_DIR/data"
touch "$SITE_DIR/data/counter.txt"
chown -R www-data:www-data "$SITE_DIR/data"

echo "==> Writing nginx config"
cat > /etc/nginx/sites-available/ozzyhelix.xyz <<EOF
server {
    listen 80;
    server_name _;

    root $SITE_DIR;
    index index.html;

    location ~* \.(css|js|svg|woff2?|png|jpg|jpeg|gif|webp|mp3|ogg|wav)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.html$ {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }

    # Keep the counter's state file private
    location ^~ /data/ {
        deny all;
        return 404;
    }

    # PHP pages (visitor counter)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
    }

    # Serve the license inline instead of downloading it
    location = /LICENSE {
        default_type text/plain;
        add_header Content-Disposition "inline";
        add_header Cache-Control "no-cache";
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ozzyhelix.xyz /etc/nginx/sites-enabled/ozzyhelix.xyz
nginx -t
systemctl enable --now nginx

echo
echo "Done. The site is served on the local NAT at http://<container-ip>/"
echo "Find the IP with:  ip a | grep inet"
