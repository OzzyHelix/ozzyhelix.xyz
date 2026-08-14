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

## License

Licensed under the GNU General Public License v2.0. See [LICENSE](LICENSE).
