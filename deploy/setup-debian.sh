#!/usr/bin/env bash
# One-time setup for serving ozzyhelix.xyz through a Cloudflare Tunnel
# on a Debian LXC container inside Proxmox.
#
# Requirements:
#   - A Cloudflare account with the domain's DNS managed by Cloudflare
#   - The site files copied to the container (see "Copy the site" below)
#
# Usage:
#   bash setup-debian.sh [domain] [site-source-dir]
#
# Examples:
#   bash setup-debian.sh                          # uses ozzyhelix.xyz and /opt/ozzyhelix-site
#   bash setup-debian.sh ozzyhelix.xyz /var/www/ozzyhelix.xyz
#
# The script is interactive once: `cloudflared tunnel login` prints a URL
# you must open in your browser on any machine to authorize the tunnel.

set -euo pipefail

DOMAIN="${1:-ozzyhelix.xyz}"
WWW_DOMAIN="www.${DOMAIN}"
SITE_SRC="${2:-/opt/ozzyhelix-site}"
SITE_DIR="/var/www/ozzyhelix.xyz"
TUNNEL_NAME="ozzyhelix"
CLOUDFLARED_DIR="/etc/cloudflared"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash setup-debian.sh" >&2
    exit 1
fi

echo "==> Installing nginx and curl"
apt-get update
apt-get install -y nginx curl

echo "==> Installing cloudflared"
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared debian bookworm main" > /etc/apt/sources.list.d/cloudflared.list
apt-get update
apt-get install -y cloudflared

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
    server_name $DOMAIN $WWW_DOMAIN;

    root $SITE_DIR;
    index index.html;

    location ~* \.(css|js|svg|woff2?|png|jpg|jpeg|gif|webp)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location = /index.html {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
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

echo "==> Authorizing Cloudflare (open the printed URL in your browser)"
cloudflared tunnel login

echo "==> Creating tunnel '$TUNNEL_NAME'"
cloudflared tunnel create "$TUNNEL_NAME"

TUNNEL_ID=$(cloudflared tunnel list --output json | python3 -c "import json,sys; d=json.load(sys.stdin); print([t['id'] for t in d if t['name']=='$TUNNEL_NAME'][0])")
CRED_FILE="$HOME/.cloudflared/$TUNNEL_ID.json"

echo "==> Writing tunnel config"
mkdir -p "$CLOUDFLARED_DIR"
cp "$CRED_FILE" "$CLOUDFLARED_DIR/$TUNNEL_ID.json"
cat > "$CLOUDFLARED_DIR/config.yml" <<EOF
tunnel: $TUNNEL_ID
credentials-file: $CLOUDFLARED_DIR/$TUNNEL_ID.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - hostname: $WWW_DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF

echo "==> Routing DNS records"
cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN"
cloudflared tunnel route dns "$TUNNEL_NAME" "$WWW_DOMAIN"

echo "==> Installing and starting the tunnel as a system service"
cloudflared --config "$CLOUDFLARED_DIR/config.yml" service install
systemctl enable --now cloudflared
sleep 3
systemctl status cloudflared --no-pager || true

echo
echo "Done. Your site should be live at https://$DOMAIN once DNS propagates."
echo "Check it with:  curl -sI https://$DOMAIN"
