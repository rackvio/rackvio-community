# Rackvio Community Edition -- Installation Guide

This guide gets you from zero to a running Rackvio instance in under 5 minutes.

## System Requirements

| Requirement       | Minimum             |
| ----------------- | ------------------- |
| Docker            | 24.0+               |
| Docker Compose    | v2 (bundled with Docker Desktop) |
| RAM               | 4 GB                |
| CPU               | 2 cores             |
| Disk              | 10 GB free          |
| Operating System  | Linux, macOS, or Windows (with WSL2) |

Rackvio runs entirely in Docker containers. No additional runtime (Node.js, Python, PostgreSQL) needs to be installed on the host.

## Quick Start

```bash
# 1. Download the compose file and environment template
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/rackvio/rackvio-community/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/rackvio/rackvio-community/main/.env.example

# 2. Create your environment file
cp .env.example .env

# Edit .env -- at minimum set:
#   PLATFORM_ADMIN_EMAIL=you@yourcompany.com
#   AUTH_SECRET=<64-char random string>
# Generate AUTH_SECRET:
#   openssl rand -base64 48 | tr -d '=+/' | cut -c1-64

# 3. Start the stack (pulls prebuilt images from GHCR)
docker compose up -d
```

Startup takes 30-60 seconds on first run while images pull from GitHub Container Registry and PostgreSQL initializes. Watch progress with:

```bash
docker compose logs -f
```

## First Login

On first startup with `DEPLOYMENT_MODE=self_hosted` (the default), Rackvio auto-creates a bootstrap admin account and prints a randomly generated temporary password to the backend logs.

Read the temporary password from the logs:

```bash
docker compose logs backend | grep -iA 1 "temporary password"
```

You should see a block like:

```
  =============================================
  Bootstrap admin created
  Email: you@yourcompany.com
  Temporary password: 1a2b3c4d5e6f7890
  Change this password after first login.
```

Then:

1. Open `http://localhost:3000` and click **Sign in**.
2. Enter the email from `PLATFORM_ADMIN_EMAIL` and the temporary password from the logs.
3. You will be required to set a new password before reaching the dashboard.
4. You now have full admin access to the single-tenant instance.

A persistent warning banner is shown while logged in as the bootstrap admin. This is the signal that the account should be rotated or disabled before production use.

### Resetting the Bootstrap Admin Password

If you lose the temporary password, reset it via the CLI:

```bash
docker compose exec backend rackvio admin reset-password you@yourcompany.com
```

The command prompts for a new password (input hidden, confirmed), writes the bcrypt hash to the user record, and you can log in immediately with the new credentials.

## Loading Demo Data

To populate Rackvio with a realistic 50-rack colo facility for evaluation and demos:

```bash
docker compose run --rm --entrypoint python backend -m app.seed.demo_seed
```

This creates:
- **1 site** (East Coast DC Site) with 2 buildings
- **4 rooms** across the buildings (Production, Network Core, DR Primary, Storage)
- **50 racks** (42U each) distributed across rooms
- **~150-200 assets** (Dell servers, Cisco switches, APC PDUs, Panduit patch panels)
- **Full power tree** with utility feeds, UPS, floor PDUs, rack PDUs, and outlets
- **IP allocations** with 10.0.0.0/16 supernet and 3 subnets (~50 IP assignments)

The seed script is idempotent -- running it again is a no-op if the demo organization already exists.

## Importing Your Data

Rackvio supports CSV import for bulk asset onboarding, with a dry-run validation pass that reports errors before any rows are written.

### CSV Format

| Column              | Required | Description                              |
| ------------------- | -------- | ---------------------------------------- |
| `name`              | Yes      | Asset name (unique within rack)          |
| `equipment_model`   | Yes      | Equipment model name (must exist in catalog) |
| `rack`              | Yes      | Rack name (must exist in location hierarchy) |
| `u_position`        | No       | Rack unit position (bottom of device)    |
| `face`              | No       | `front` or `rear` (default: `front`)     |
| `lifecycle_state`   | No       | `planned`, `installed`, `reserved`, `decommissioned` |

### Example CSV

```csv
name,equipment_model,rack,u_position,face,lifecycle_state
WEB-SRV-01,Dell PowerEdge R760,A1-01,1,front,installed
WEB-SRV-02,Dell PowerEdge R760,A1-01,3,front,installed
CORE-SW-01,Cisco Catalyst 9300,A1-01,42,front,installed
```

### Import Steps

1. Navigate to **Assets** in the sidebar.
2. Click the **Import** button.
3. Upload your CSV file.
4. Review the dry-run preview (shows which rows will be inserted and any validation errors).
5. Confirm to commit the import.

## Configuration

All configuration is via environment variables in the `.env` file.

### Required Variables

| Variable                   | Description                                     |
| -------------------------- | ----------------------------------------------- |
| `PLATFORM_ADMIN_EMAIL`     | Email for the auto-provisioned bootstrap admin  |
| `AUTH_SECRET`              | 64-char random string for JWT signing           |

### Database

| Variable              | Default       | Description                                    |
| --------------------- | ------------- | ---------------------------------------------- |
| `DB_PASS`             | `devpassword` | PostgreSQL superuser password                  |
| `APP_DB_PASS`         | `devpassword` | Application role (`rackvio_app`, no BYPASSRLS) |
| `MIGRATIONS_DB_PASS`  | `devpassword` | Migrations role (`rackvio_migrations`, BYPASSRLS) |

For production, generate a unique strong password for each of the three roles:

```bash
openssl rand -base64 24 | tr -d '=+/'  # DB_PASS
openssl rand -base64 24 | tr -d '=+/'  # APP_DB_PASS
openssl rand -base64 24 | tr -d '=+/'  # MIGRATIONS_DB_PASS
```

Change the passwords before first startup. Changing them afterwards requires manually updating the PostgreSQL roles (see Troubleshooting).

### Deployment Mode

| Variable              | Default         | Description                                    |
| --------------------- | --------------- | ---------------------------------------------- |
| `DEPLOYMENT_MODE`     | `self_hosted`   | `self_hosted` enables the bootstrap admin auto-provisioning. `saas` disables it (used by the hosted Cloud deployments). |
| `ALLOWED_ORIGINS`     | `http://localhost:3000` | CORS allowed origins (comma-separated) |

### Equipment Library Sync

| Variable              | Default         | Description                                    |
| --------------------- | --------------- | ---------------------------------------------- |
| `RACKVIO_SYNC_MODE`   | `airgapped`     | `airgapped`, `online`, or `both`               |
| `RACKVIO_LIBRARY_URL` | _(empty)_       | Required when `RACKVIO_SYNC_MODE` is `online` or `both` |

In `airgapped` mode (the default), the equipment catalog only accepts signed ZIP bundles uploaded through the admin UI. See [Network Traffic Policy](/network-traffic-policy) for the full outbound-connection breakdown.

### SMTP (optional, for invitation emails)

User invitation emails fall back to stdout logging when SMTP is unset. Set these to deliver real emails:

| Variable          | Description                                |
| ----------------- | ------------------------------------------ |
| `SMTP_HOST`       | SMTP relay hostname                        |
| `SMTP_PORT`       | Default `587`                              |
| `SMTP_USE_TLS`    | Default `true`                             |
| `SMTP_USERNAME`   | SMTP auth user                             |
| `SMTP_PASSWORD`   | SMTP auth password                         |
| `SMTP_FROM_EMAIL` | From address (default `noreply@rackvio.local`) |
| `APP_BASE_URL`    | Public URL used to construct invite links (e.g. `https://dcim.example.com`) |

## Exposing Rackvio on the Public Internet

The Community Edition compose file binds only to `localhost:3000` and `localhost:8000` -- you bring your own reverse proxy (nginx, Caddy, Traefik, AWS ALB, Cloudflare Tunnel, etc.) for TLS termination and public DNS.

At minimum your proxy should:

1. Terminate TLS (Let's Encrypt or your own certificate)
2. Proxy `/` to frontend `localhost:3000`
3. Proxy `/api` to backend `localhost:8000`
4. Preserve `X-Forwarded-For` / `X-Forwarded-Proto` headers

Then update `.env`:

```bash
AUTH_URL=https://dcim.yourcompany.com
NEXT_PUBLIC_API_URL=https://dcim.yourcompany.com/api
ALLOWED_ORIGINS=https://dcim.yourcompany.com
APP_BASE_URL=https://dcim.yourcompany.com
```

## Air-Gapped Deployment

Rackvio Community Edition is designed for air-gapped operation. By default, the application makes **zero outbound network connections**.

To deploy in a fully air-gapped environment:

1. On a machine with internet access, pull and save the Docker images:
   ```bash
   docker compose pull
   docker save ghcr.io/rackvio/rackvio-backend:latest ghcr.io/rackvio/rackvio-frontend:latest \
     pgvector/pgvector:pg16 redis:7-alpine | gzip > rackvio-images.tar.gz
   ```

2. Transfer `rackvio-images.tar.gz`, your `docker-compose.yml`, and the `.env` file to the air-gapped machine.

3. Load the images:
   ```bash
   docker load < rackvio-images.tar.gz
   ```

4. Start normally:
   ```bash
   docker compose up -d
   ```

The equipment library stays in `airgapped` mode by default (see `RACKVIO_SYNC_MODE`). New device types can be loaded from signed ZIP bundles uploaded through the admin UI.

See the [Network Traffic Policy](/network-traffic-policy) for the complete network traffic audit.

## Backup and Restore

Data is persisted in Docker volumes (`pg_data`, `redis_data`) and survives container recreation.

Back up the database before upgrading or on a schedule:

```bash
docker compose exec postgres \
  pg_dump -U postgres rackvio > backup-$(date +%Y%m%d).sql
```

Restore from a dump:

```bash
docker compose exec -T postgres \
  psql -U postgres -d rackvio < backup-YYYYMMDD.sql
```

## Upgrading

```bash
# 1. Pull the latest images
docker compose pull

# 2. Restart with the new images
docker compose up -d

# 3. Database migrations run automatically on backend startup
```

Back up first (see above). Migrations are forward-only -- there is no automatic downgrade path. To roll back, restore from the pre-upgrade backup.

## Recovery

Rackvio ships with a break-glass CLI for operators who have lost UI access — for example, when org-wide **Require SSO** is on and the SSO provider is misconfigured. The CLI bypasses every authentication check and talks directly to the database.

**Threat model:** access to these commands implies access to the host or container shell. This is the "keys to the building" assumption — if an attacker can already exec into the backend container, they can already read the database directly. The CLI is not an additional privilege escalation surface; it is a thin, audited wrapper around the recovery operations an operator would otherwise perform by hand.

Every invocation of an `admin` subcommand appends a row to the `audit_events` table under one of the `sso_*` or `sso_cli_*` event types, so recovery actions remain traceable.

### Available commands

Run `rackvio admin --help` inside the backend container to see the full list. All three commands below are documented with `--help` on each subcommand.

#### `rackvio admin reset-password <email>`

Resets the password for a local (non-SSO) user. Prompts for the new password with hidden input and confirmation. Writes the bcrypt hash directly to `users.password_hash` — the user can log in via `/auth/bootstrap/login` on the next request.

```bash
docker compose exec backend rackvio admin reset-password admin@example.com
```

Use when: the admin UI is unavailable (e.g. SSO is required org-wide and the SSO provider is broken) and you need to restore password access for a specific admin.

Audit event emitted: `sso_cli_password_reset`.

#### `rackvio admin promote-bootstrap <email>`

Sets `users.is_bootstrap_admin = true` on the named user. The bootstrap admin flag re-activates the special first-login flow and the "bootstrap admin" banner in the UI, and is recognized by the `/auth/bootstrap/login` endpoint even when other safety gates are tripped.

```bash
docker compose exec backend rackvio admin promote-bootstrap admin@example.com
```

Use when: the original bootstrap admin has been deactivated or deleted, and you need to designate a new one without going through the UI.

Audit event emitted: `sso_cli_bootstrap_promoted`.

#### `rackvio admin disable-sso-requirement <org_name|all>`

Clears the org-wide `organizations.require_sso` flag. Accepts either a specific organization name (exact match, case-insensitive) or the literal `all` to clear the flag across every org in a multi-tenant deployment.

```bash
# Single org
docker compose exec backend rackvio admin disable-sso-requirement "Default Organization"

# Every org (SaaS multi-tenant)
docker compose exec backend rackvio admin disable-sso-requirement all
```

Use when: the "Require SSO" safety gate was enabled before the SSO provider was fully verified, and every admin account has been locked out of the UI.

Audit event emitted: `sso_require_sso_disabled` (one row per affected org).

### Recovery playbook

If password admins have been locked out by a misconfigured SSO setup, run the three commands in this order:

```bash
# 1. Clear the org-wide gate so password login will accept credentials again
docker compose exec backend rackvio admin disable-sso-requirement all

# 2. Reset a known admin's password
docker compose exec backend rackvio admin reset-password admin@example.com

# 3. (Optional) re-flag the admin as bootstrap admin so the banner shows on
#    next login and reminds them to re-check SSO configuration before turning
#    the org-wide toggle back on.
docker compose exec backend rackvio admin promote-bootstrap admin@example.com
```

Each command is idempotent and safe to re-run.

## Enterprise-Only Features (Not in Community)

The Community Edition ships the core DCIM feature set described above. The following capabilities are **not** in the community build -- they are stripped at build time via `Dockerfile.community` and webpack module replacement. Routes for these features return HTTP 404 in community:

- **SSO / OIDC login** (email-domain routing, multi-provider, admin SSO page)
- **Network auto-discovery + reconciliation** (SNMP v1/v2c/v3, LLDP/CDP)
- **Capacity reservation + what-if scenario planning**
- **Reports + CSV/PDF export** (Cloud Starter+)
- **Power gap analytics + stranded capacity reporting** (Patent #007)
- **Three-phase A/B/C circuit modeling + failover-overload detection**
- **Cabinet design vs. live load reconciliation**
- **kWh -> $ translation + per-org energy rate configuration**
- **Audit log query/export beyond access events**
- **RBAC beyond the bootstrap admin**
- **Tenant self-service portal**
- **In-app AI assistant** (read-only chat against your infrastructure data)
- **API tier with rate limits + webhooks**

If you need any of these, see [rackvio.com](https://rackvio.com) for Cloud Growth / Enterprise tiers, or [request a demo](https://rackvio.com/demo).

You can verify the enterprise routes are absent from your community build:

```bash
curl -sk http://localhost:8000/admin/sso/providers -o /dev/null -w "%{http_code}\n"
# Expect: 404
```

## Troubleshooting

### Port conflict on 3000 or 8000

Another service is using the port. Either stop the conflicting service or remap ports in `docker-compose.yml`:

```yaml
ports:
  - "3001:3000"  # Change host port (left side)
```

### Can't log in as bootstrap admin

- Confirm `DEPLOYMENT_MODE=self_hosted` in `.env` (the `saas` mode skips bootstrap auto-provisioning entirely).
- Check the backend logs for the temporary-password banner: `docker compose logs backend | grep -iA 1 "temporary password"`. If the block is not there, the auto-provisioning ran on a different startup -- reset the password via `rackvio admin reset-password <email>`.
- Confirm the email matches `PLATFORM_ADMIN_EMAIL` in `.env` exactly.
- Check backend logs for auth errors: `docker compose logs backend | grep -i auth`.

### Database authentication failed after changing passwords

If you changed `DB_PASS`, `APP_DB_PASS`, or `MIGRATIONS_DB_PASS` in `.env` after the first startup, the PostgreSQL roles still have the old passwords. Either:

- **Reset volumes** (destroys data):
  ```bash
  docker compose down -v
  docker compose up -d
  ```
- **Update roles manually**: connect to PostgreSQL and run:
  ```sql
  ALTER ROLE rackvio_app WITH PASSWORD 'new_app_password';
  ALTER ROLE rackvio_migrations WITH PASSWORD 'new_migrations_password';
  ```

### Backend health check failing

```bash
docker compose logs backend
```

Common causes:
- PostgreSQL not ready yet (wait 30s and retry)
- Invalid `DATABASE_URL` in `.env`
- Missing required env vars (`AUTH_SECRET`, `PLATFORM_ADMIN_EMAIL`)
- Migrations role lacks `BYPASSRLS` -- re-run the `db/init` scripts

### Containers keep restarting

```bash
# Check which container is failing
docker compose ps

# View its logs
docker compose logs <service-name>
```

### Reset everything

To wipe all data and start fresh:

```bash
docker compose down -v
docker compose up -d
```

This destroys all database data and Redis cache. Use only as a last resort.
