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

## Upgrading to 1.2.3

**1.2.3 — security updates only.** From 1.2.2, pull the new images and restart
(`docker compose pull`, then `docker compose up -d`); if you pin `RACKVIO_VERSION` in `.env`, set it
to `1.2.3` first. There is no functional change and no new setting: `.env` and `docker-compose.yml`
stay as they are.

- **Security updates:** Next.js 15.5.27 and sharp 0.35.5 in the web app; pyasn1 0.6.4 and WeasyPrint
  70 in the backend. Each fixes published security advisories in the version 1.2.2 shipped.
- **Next.js's image optimiser is switched off.** Rackvio never used it, so nothing on screen changes;
  `/_next/image` now answers 404.

Coming from 1.2.1 or earlier? Read [Upgrading to 1.2.2](#upgrading-to-122) first.

## Upgrading to 1.2.2

> [!IMPORTANT]
> **Before you upgrade to 1.2.2: check `AUTH_SECRET`.** From 1.2.2, Rackvio will not start while
> `AUTH_SECRET` in `.env` is still the example value from `.env.example`. `docker compose up -d`
> stops with "dependency failed to start", and `docker compose logs backend` shows "Rackvio will not
> start: AUTH_SECRET … is still an example value". Generate your own with `openssl rand -hex 32`, put
> it in `.env` as `AUTH_SECRET=<the new value>`, then run `docker compose up -d`. Everyone is signed
> out once. If anyone uses two-factor authentication, they sign in with one of their recovery codes
> and set two-factor up again, or an administrator resets it in Admin > Users. Do not set
> `MFA_ENCRYPTION_KEY` to the key `rackvio admin mfa-print-key` printed while the example value was
> in use: anyone can compute that key, and 1.2.2 refuses it too.

Follow [Upgrade](INSTALL.md#upgrade). Also new in 1.2.2:

- **Floor-plan drawings** now live on their own `uploads` volume. The first time you upgrade to this
  compose file, copy them out before you replace `docker-compose.yml` —
  [Upgrade](INSTALL.md#upgrade) shows how.
- **One port.** The web app and the API share port 3000 (`RACKVIO_PORT`), with the API at `/api`;
  port 8000 is no longer published. Scripts that called `http://<your-server>:8000/...` now call
  `http://<your-server>:3000/api/...`.
- **Password-reset links** emailed in the 15 minutes before the upgrade stop working. Ask for a new
  one, or an administrator creates one in Admin > Users.
- **3D room view labels** now use a font that ships with Rackvio (Inter), so the 3D view no longer
  contacts cdn.jsdelivr.net and its labels show on servers without internet access. Characters Inter
  does not include (for example Chinese, Japanese, Korean, Arabic or emoji in rack names) show as
  boxes in the 3D view. The rest of the app is unchanged.

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
