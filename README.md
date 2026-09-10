# ozzyhelix.xyz

Personal homepage for Ozzy Helix — dark, flat, and running on plain HTML/CSS + a little PHP behind nginx.

## Files

```
index.html                  Home page
timer.html                  Countdown timer page
counter.php                 1990s-style visitor counter (odometer SVG image)
styles.css                  Site-wide styles
timer.css                   Timer page styles
nginx.conf.example          Nginx site config (TLS, caching, PHP-FPM)
LICENSE                     GPL-2.0 license
assets/
  Ozzy-anime-profile-picture.svg   Profile picture (header)
  moon2021.png                     Favicon
  beeper.mp3                       Timer alarm
data/
  counter.txt                      Visitor counter state
deploy/
  setup-debian.sh                  One-shot nginx + PHP-FPM setup for Debian
  cloudflared.yml.example          Cloudflare Tunnel reference config
```

## Visitor counter

The footer counter is `counter.php`, which runs behind PHP-FPM and stores its count in `data/counter.txt`. Each normal request to the image increments the count.

- `counter.php` — odometer image (increments)
- `counter.php?view=1` — odometer image, no increment
- `counter.php?raw=1` — plain zero-padded number
- `counter.php?reset=1` — zero the count
- `counter.php?set=1234` — set the count

Notes:

- Requires nginx + PHP-FPM (`php-fpm` on Debian).
- `deploy/setup-debian.sh` installs PHP-FPM and wires up the FastCGI socket automatically.
- `data/counter.txt` must be writable by the web user (`www-data`). The setup script handles this.
- The counter is reset by `?reset=1`; redeploying via `rsync -a` (no `--delete`) preserves the live count.

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

## Deploy on a Debian LXC container (Proxmox, local NAT)

Serves the site from a container on your local network via nginx. Cloudflare Tunnel can be added later.

1. **Copy the site to the container** (from any machine with this repo):
   ```
   rsync -avz ./ user@container:/opt/ozzyhelix-site/
   ```
2. **SSH into the container** and run the setup script:
   ```
   sudo bash /opt/ozzyhelix-site/deploy/setup-debian.sh
   ```
   It installs nginx + PHP-FPM, configures it, and copies the site to `/var/www/html` (your nginx web root). Pass a different destination as the second arg if yours differs:
   ```
   sudo bash /opt/ozzyhelix-site/deploy/setup-debian.sh /opt/ozzyhelix-site /var/www/html
   ```
3. Open `http://<container-ip>/` from anything on the LAN.

### Adding a Cloudflare Tunnel later

Reference config lives in `deploy/cloudflared.yml.example`. After installing `cloudflared`, create a tunnel pointing at `http://localhost:80`, route DNS for your domain, and install it as a systemd service.

## License

Licensed under the GNU General Public License v2.0. See [LICENSE](LICENSE).
