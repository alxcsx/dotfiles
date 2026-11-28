# Static site hosting

Connect to your tailnet and open `https://<host>.<tailnet>.ts.net:8444/`
(served on port `8444` via `tailscale serve`, backed by `localhost:58111`).
The user is `admin`. To recover the initial randomly generated password on the server:

```sh
journalctl --user -u site-uploads.service --no-pager | rg 'randomly generated password'
```

Change the password in File Browser Next after signing in. Create a folder named
for the desired subdomain, such as `portfolio`, then drag the **built site files**
into that folder with `index.html` at its root. It is immediately public at
`https://portfolio.<your-domain>/`. Existing explicit DNS records (such as `hermes`,
`mc`, and your other service subdomains) take precedence over the wildcard.

The uploader is tailnet-only; everything in a site folder is public. Site files
live at `~/services/static-sites/sites` and are included in the services backup.
The user Quadlets are symlinks to this directory. Caddy serves the folders on
`localhost:58110`; File Browser Next listens on `localhost:58111`. Your Cloudflare
tunnel routes `*.<your-domain>` to Caddy; a proxied wildcard DNS
CNAME points to that tunnel. Both depend on the server being awake.

To disable the private upload route: `tailscale serve --https=8444 off`.
To disable hosting, stop `static-sites.service` and `site-uploads.service`,
remove the wildcard ingress rule from `~/services/hermes-pwa/cloudflared.yml`,
restart `cloudflared-hermes.service`, and delete the wildcard DNS CNAME.
