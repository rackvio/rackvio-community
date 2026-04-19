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
# 1. Download the compose file, database init script, and environment template
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/rackvio/rackvio-community/main/docker-compose.yml
curl -fsSL -o db-init.sh https://raw.githubusercontent.com/rackvio/rackvio-community/main/db-init.sh
curl -fsSL -o .env.example https://raw.githubusercontent.com/rackvio/rackvio-community/main/.env.example

# 2. Configure
cp .env.example .env

# 3. Edit .env -- set at minimum:
#    PLATFORM_ADMIN_EMAIL=you@yourcompany.com
#    AUTH_SECRET=<64-char random string>
#    Generate a secret: openssl rand -base64 48 | tr -d '=+/' | cut -c1-64

# 4. Start the stack
docker compose up -d

# 5. Open Rackvio at http://localhost:3000
```

Images pull from GitHub Container Registry. First startup takes 30-60 seconds while PostgreSQL initializes. Watch progress with:

```bash
docker compose logs -f
```

## First Login

Rackvio Community Edition uses a **bootstrap admin** flow for the first login:

1. Open `http://localhost:3000` in your browser.
2. Click **Sign in** on the login page.
3. Enter the email address you set in `PLATFORM_ADMIN_EMAIL`.
4. Set a password when prompted. This creates the platform admin account.
5. You now have full admin access to the single-tenant instance.

The bootstrap admin account is only available when `DEPLOYMENT_MODE=self_hosted` (the default). Once you configure OIDC/SSO, you can optionally disable the bootstrap admin.

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

Rackvio supports CSV import for bulk asset onboarding.

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
4. Review the import preview and confirm.

## Configuration

All configuration is via environment variables in the `.env` file.

### Required Variables

| Variable                | Description                                   |
| ----------------------- | --------------------------------------------- |
| `PLATFORM_ADMIN_EMAIL`  | Email for the bootstrap admin account         |
| `AUTH_SECRET`           | 64-char random string for JWT signing         |

### Optional Variables

| Variable              | Default         | Description                                    |
| --------------------- | --------------- | ---------------------------------------------- |
| `DB_PASS`             | `devpassword`   | PostgreSQL superuser password                  |
| `APP_DB_PASS`         | `devpassword`   | Application database role password             |
| `MIGRATIONS_DB_PASS`  | `devpassword`   | Migrations database role password              |
| `DEPLOYMENT_MODE`     | `self_hosted`   | `self_hosted` or `saas`                        |
| `ALLOWED_ORIGINS`     | `http://localhost:3000` | CORS allowed origins (comma-separated)  |
| `RACKVIO_SYNC_MODE`   | `airgapped`     | Device library sync: `airgapped`, `online`, `both` |

### Database Passwords

For production deployments, change all three database passwords from their defaults:

```bash
# Generate secure passwords
openssl rand -base64 24 | tr -d '=+/'  # DB_PASS
openssl rand -base64 24 | tr -d '=+/'  # APP_DB_PASS
openssl rand -base64 24 | tr -d '=+/'  # MIGRATIONS_DB_PASS
```

Update `.env` with the generated values before first startup. Changing passwords after initial setup requires manually updating the PostgreSQL roles.

## Air-Gapped Deployment

Rackvio Community Edition is designed for air-gapped operation. By default, the application makes **zero outbound network connections**.

To deploy in a fully air-gapped environment:

1. On a machine with internet access, pull and save the images:
   ```bash
   docker pull ghcr.io/rackvio/rackvio-backend:latest
   docker pull ghcr.io/rackvio/rackvio-frontend:latest
   docker pull pgvector/pgvector:pg16
   docker pull redis:7-alpine
   docker save ghcr.io/rackvio/rackvio-backend:latest \
     ghcr.io/rackvio/rackvio-frontend:latest \
     pgvector/pgvector:pg16 redis:7-alpine | gzip > rackvio-images.tar.gz
   ```

2. Transfer `rackvio-images.tar.gz`, `docker-compose.yml`, and `.env` to the air-gapped machine.

3. Load the images:
   ```bash
   docker load < rackvio-images.tar.gz
   ```

4. Start normally:
   ```bash
   docker compose up -d
   ```

The device library operates in `airgapped` mode by default (see `RACKVIO_SYNC_MODE`). Equipment models can be loaded from signed ZIP bundles uploaded through the UI.

See [NETWORK-TRAFFIC-POLICY.md](NETWORK-TRAFFIC-POLICY.md) for the complete network traffic audit.

## Building from Source

If you prefer to build the images yourself instead of pulling from GHCR:

```bash
git clone https://github.com/rackvio/rackvio-community.git
cd rackvio-community
cp .env.example .env
# edit .env
docker compose -f docker-compose.community.yml up -d
```

This builds the images locally using `Dockerfile.community`.

## Upgrading

```bash
# Pull the latest images
docker compose pull

# Restart with new images
docker compose up -d

# Database migrations run automatically on backend startup
```

Your data is persisted in Docker volumes (`pg_data`, `redis_data`) and survives container recreation. To back up before upgrading:

```bash
docker compose exec postgres pg_dump -U postgres rackvio > backup-$(date +%Y%m%d).sql
```

## Troubleshooting

### Port conflict on 3000 or 8000

Another service is using the port. Either stop the conflicting service or remap ports in `docker-compose.yml`:

```yaml
ports:
  - "3001:3000"  # Change host port (left side)
```

### Database authentication failed

If you changed database passwords in `.env` after initial setup, the PostgreSQL roles still have the old passwords. Either:

- **Reset volumes** (destroys data): `docker compose down -v && docker compose up -d`
- **Update roles manually**: connect to PostgreSQL and run `ALTER ROLE rackvio_app WITH PASSWORD 'new_password';`

### No data showing after login

- Verify you are logged in as the `PLATFORM_ADMIN_EMAIL` user.
- Run the demo seed script (see "Loading Demo Data" above) to populate sample data.
- Check backend logs: `docker compose logs backend`

### Backend health check failing

```bash
# Check backend logs for startup errors
docker compose logs backend

# Common causes:
# - PostgreSQL not ready yet (wait 30s and retry)
# - Invalid DATABASE_URL in .env
# - Missing required env vars (AUTH_SECRET, PLATFORM_ADMIN_EMAIL)
```

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
