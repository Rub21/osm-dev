# proxy

Shared Traefik reverse proxy for multiple osm-dev instances. Handles HTTPS via Let's Encrypt and routes by subdomain.

## Start

```bash
cd /apps/osm-dev/proxy
docker compose up -d
```

Exposes ports 80, 443, and 8080 (dashboard at http://localhost:8080).

Creates external network `osm-proxy`. Each osm-dev instance joins this network and registers Traefik labels to be routed.

## Requirements

- Ports 80 and 443 open on host (Let's Encrypt HTTP-01 challenge needs port 80).
- DNS pointing at host IP. nip.io works out of the box: `anything.<IP-with-dashes>.nip.io`.

## Stop

```bash
docker compose down
```

Volume `letsencrypt` persists certificates. Do not delete it unless needed; Let's Encrypt rate-limits issuance.
