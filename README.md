# Rackvio Community Edition

Self-hosted data center infrastructure management. Zero telemetry, zero outbound connections.

> [!WARNING]
> **Security notice (2026-09-26):** frontend images `0.1.0`–`0.2.2` contain a critical remote code
> execution vulnerability (CVE-2025-55182). If you installed before 14 June 2026 and have not pulled
> since, upgrade now. See the advisory
> [GHSA-vx55-jjvc-c4v4](https://github.com/rackvio/rackvio-community/security/advisories/GHSA-vx55-jjvc-c4v4)
> for how to check your version and upgrade safely.

## Install

```bash
cp .env.example .env
# Edit .env — set PLATFORM_ADMIN_EMAIL and AUTH_SECRET
docker compose up -d
```

Open http://localhost:3000. Check the backend logs for your temporary admin password:

```bash
docker compose logs backend | grep -i "temporary password"
```

## Load Demo Data

```bash
docker compose run --rm --entrypoint python backend -m app.seed.demo_seed
```

## Docs

- [Installation Guide](INSTALL.md)
- [Network Traffic Policy](NETWORK-TRAFFIC-POLICY.md)
