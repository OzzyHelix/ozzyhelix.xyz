# ozzyhelix.xyz

Personal homepage for Ozzy Helix — dark, flat, and running on plain HTML/CSS behind nginx.

## Files

```
index.html                  Home page
styles.css                  Site-wide styles
nginx.conf.example          Nginx site config (TLS, caching)
LICENSE                     GPL-2.0 license
assets/
  Ozzy-anime-profile-picture.svg   Profile picture (header)
  moon2021.png                     Favicon
```

## Deployment

1. Copy the repo to the web root:
   ```
   sudo mkdir -p /var/www/ozzyhelix.xyz
   sudo cp -r . /var/www/ozzyhelix.xyz/
   ```
2. Install the nginx site:
   ```
   sudo cp nginx.conf.example /etc/nginx/sites-available/ozzyhelix.xyz
   sudo ln -s /etc/nginx/sites-available/ozzyhelix.xyz /etc/nginx/sites-enabled/
   ```
3. Enable TLS with certbot:
   ```
   sudo certbot --nginx -d ozzyhelix.xyz -d www.ozzyhelix.xyz
   ```
4. Test and reload:
   ```
   sudo nginx -t && sudo systemctl reload nginx
   ```

## Local preview

No build step needed — just serve the directory statically:

```
python3 -m http.server 8080
```

Then open http://localhost:8080.

## Deploy via Cloudflare Tunnel (Debian LXC on Proxmox)

Serves the site from a container through Cloudflare — no open ports, no certbot, no public IP needed.

1. **Copy the site to the container** (from any machine with this repo):
   ```
   rsync -avz ./ user@container:/opt/ozzyhelix-site/
   ```
2. **SSH into the container** and run the setup script:
   ```
   sudo bash /opt/ozzyhelix-site/deploy/setup-debian.sh
   ```
   It installs nginx + cloudflared, configures nginx, and creates the tunnel.
3. **Authorize when prompted** — `cloudflared tunnel login` prints a URL to open in your browser.
4. DNS records are created automatically via `cloudflared tunnel route dns`.

Files in `deploy/`:
- `setup-debian.sh` — one-time installer (idempotent-ish, safe to re-run)
- `cloudflared.yml.example` — reference tunnel config (the script generates the real one)

For a pre-existing nginx setup pointing at `$SITE_DIR`, just run the tunnel part: install `cloudflared`, create the tunnel, and start the service.

## License

Licensed under the GNU General Public License v2.0. See [LICENSE](LICENSE).
