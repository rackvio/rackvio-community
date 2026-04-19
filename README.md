# Rackvio Community Edition

Self-hosted data center infrastructure management. Zero telemetry, zero outbound connections.

## Install

```bash
cp .env.example .env
# Edit .env — set PLATFORM_ADMIN_EMAIL and AUTH_SECRET
docker compose up -d
```

Open http://localhost:3000. Check the backend logs for your temporary admin password:

```bash
docker compose logs backend | grep "temporary password"
```

## Load Demo Data

```bash
docker compose run --rm --entrypoint python backend -m app.seed.demo_seed
```

## Docs

- [Installation Guide](INSTALL.md)
- [Network Traffic Policy](NETWORK-TRAFFIC-POLICY.md)
