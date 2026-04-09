# OSM Dev

Local development setup for openstreetmap-website.

## Setup

1. Clone both repos in the same directory:

```bash
git clone git@github.com:openstreetmap/openstreetmap-website.git
git clone git@github.com:rub21/osm-dev.git
```

The structure should look like:

```
├── openstreetmap-website/
└── osm-dev/
```

2. Build and run:

```bash
cd osm-dev
docker compose build
docker compose up
```

The app will be available at http://localhost:3000

## Configuration

- `config/database.yml` - Database connection
- `config/settings.local.yml` - App settings (overrides `settings.yml`)
- `config/storage.yml` - Storage config
- `.env` - Environment variables
- `start.sh` - Startup script (restores DB, runs migrations, starts server)

## HTTPS con Certbot

Para habilitar HTTPS con un certificado SSL gratuito de Let's Encrypt:

```bash
docker exec proxy sh -c 'apk add certbot certbot-nginx && certbot --nginx -d openstreetmap.204-168-242-139.nip.io --non-interactive --agree-tos -m rub2106@gmail.com'
```