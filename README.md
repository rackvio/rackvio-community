# Rackvio Community Edition

Self-hosted data center infrastructure management. Zero telemetry, zero outbound connections.

> [!WARNING]
> **Security notice (2026-09-26):** frontend images `0.1.0`–`0.2.2` contain a critical remote code
> execution vulnerability (CVE-2025-55182). If you installed before 14 June 2026 and have not pulled
> since, upgrade now. See the advisory
> [GHSA-vx55-jjvc-c4v4](https://github.com/rackvio/rackvio-community/security/advisories/GHSA-vx55-jjvc-c4v4)
> for how to check your version and upgrade safely.
>
> **Also check `AUTH_SECRET` (2026-09-26):** If your `.env` still has the `AUTH_SECRET` value from `.env.example`, replace it now. The example value is not secret and must be replaced. Generate a new one with `openssl rand -hex 32`, put it in `.env`, then run `docker compose up -d --force-recreate backend frontend`. Everyone is signed out and signs in again.

## Install

```bash
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/rackvio/rackvio-community/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/rackvio/rackvio-community/main/.env.example
cp .env.example .env
# Edit .env — set PLATFORM_ADMIN_EMAIL, and set AUTH_SECRET to the output of: openssl rand -hex 32
docker compose up -d
```

Open `http://<your-server>:3000` from any computer that can reach the server. Check the backend logs
for your temporary admin password:

```bash
docker compose logs backend | grep -i "temporary password"
```

Every setting in `.env` reaches Rackvio — email, storage, the port, the address used in emailed
links. See [INSTALL.md](INSTALL.md).

> **Upgrading from an earlier compose file?** Uploaded floor-plan drawings now live on their own
> `uploads` volume. Copy them out before you replace `docker-compose.yml` — see
> [Upgrade](INSTALL.md#upgrade).

## Load demo data

On a new install, before you create any sites:

```bash
docker compose run --rm --entrypoint python backend -m app.seed.demo_seed --org-name Default
```

It adds an example colocation facility to **Default**, the organization your administrator account
belongs to. Don't add `--reset`: it deletes the organization it seeds, including its users.

## Docs

- [Installation Guide](INSTALL.md)
- [Network Traffic Policy](NETWORK-TRAFFIC-POLICY.md)
