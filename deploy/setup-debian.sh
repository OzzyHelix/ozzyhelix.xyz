#!/usr/bin/env bash
# Setup for serving ozzyhelix.xyz on a Debian LXC container inside Proxmox.
# Serves the site on the local NAT network via nginx (no Cloudflare yet).
#
# Usage:
#   bash setup-debian.sh [site-source-dir]
#
# Examples:
#   bash setup-debian.sh                          # uses /opt/ozzyhelix-site
#   bash setup-debian.sh /var/www/ozzyhelix.xyz
#
# Access the site afterwards at http://<container-ip>/

set -euo pipefail

SITE_SRC="${1:-/opt/ozzyhelix-site}"
SITE_DIR="/var/www/ozzyhelix.xyz"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash setup-debian.sh" >&2
    exit 1
fi

echo "==> Installing nginx"
apt-get update
apt-get install -y nginx rsync

echo "==> Copying the site"
mkdir -p "$SITE_DIR"
if [[ -d "$SITE_SRC" ]]; then
    rsync -a --delete "$SITE_SRC"/ "$SITE_DIR"/
    chown -R www-data:www-data "$SITE_DIR"
else
    echo "WARNING: site source $SITE_SRC not found. Drop your files into $SITE_DIR manually."
fi

echo "==> Writing nginx config"
cat > /etc/nginx/sites-available/ozzyhelix.xyz <<EOF
server {
    listen 80;
    server_name _;

    root $SITE_DIR;
    index index.html;

    location ~* \.(css|js|svg|woff2?|png|jpg|jpeg|gif|webp)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location = /index.html {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
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
