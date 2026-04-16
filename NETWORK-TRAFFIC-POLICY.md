# Rackvio Community Edition -- Network Traffic Policy

**Version:** 1.0
**Effective date:** 2026-04-13
**Applies to:** Rackvio Community Edition (self-hosted Docker deployment)

## Summary

Rackvio Community Edition makes **zero outbound network connections** by default. The Docker containers communicate only with each other on the Docker bridge network. There is no telemetry, no analytics, no phone-home, and no license verification.

## Container Communication

The Rackvio stack consists of four containers that communicate exclusively over the Docker bridge network:

```
frontend (Next.js) ---HTTP---> backend (FastAPI)
backend  (FastAPI) ---TCP----> postgres (PostgreSQL 16)
backend  (FastAPI) ---TCP----> redis (Redis 7)
```

No container initiates connections outside the Docker bridge network unless explicitly configured by the administrator (see Optional Outbound Connections below).

### Internal Traffic Matrix

| Source    | Destination | Protocol | Port | Purpose                          |
| --------- | ----------- | -------- | ---- | -------------------------------- |
| frontend  | backend     | HTTP     | 8000 | API requests (server-side)       |
| backend   | postgres    | TCP      | 5432 | Database queries                 |
| backend   | redis       | TCP      | 6379 | Sessions, cache, task queue      |

## Inbound Connections

The following ports are exposed to the host network and are configurable in `docker-compose.community.yml`:

| Port | Service  | Purpose                        | Configurable |
| ---- | -------- | ------------------------------ | ------------ |
| 3000 | frontend | Web UI (Next.js)               | Yes          |
| 8000 | backend  | REST API (FastAPI/Uvicorn)     | Yes          |

No other ports are exposed by default. PostgreSQL (5432) and Redis (6379) are accessible only within the Docker bridge network.

## Outbound Connections

### Default: None

Out of the box, Rackvio makes **zero outbound network connections**. Specifically:

- **No telemetry.** Rackvio does not collect or transmit usage data, crash reports, or diagnostics.
- **No analytics.** No third-party analytics scripts (Google Analytics, Mixpanel, Segment, etc.) are included.
- **No phone-home.** The application does not contact any Rackvio-operated server to check for updates, validate licenses, or report status.
- **No license checks.** Rackvio Community Edition has no license enforcement mechanism. It does not validate a license key against a remote server.
- **No DNS resolution for application purposes.** The application does not resolve external hostnames during normal operation.
- **No NTP.** The containers use the host system clock. No NTP servers are contacted.

### Optional: User-Configured Outbound

The following outbound connections occur **only** if the administrator explicitly configures them:

| Feature                   | Destination                    | When Active                                | Env Variable             |
| ------------------------- | ------------------------------ | ------------------------------------------ | ------------------------ |
| OIDC/SSO authentication   | Your identity provider (IdP)   | When OIDC is configured for SSO            | `OIDC_ISSUER`            |
| SMTP email delivery       | Your SMTP relay                | When SMTP is configured for invitations    | `SMTP_HOST`              |
| Device library online sync| Rackvio library endpoint       | When sync mode set to `online` or `both`   | `RACKVIO_SYNC_MODE`      |

#### OIDC/SSO

If you configure OIDC authentication (`OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`), the backend will contact your identity provider's well-known endpoint (`/.well-known/openid-configuration`) to discover token and authorization URLs. This requires DNS resolution and outbound HTTPS to your IdP.

**No OIDC traffic occurs unless you set these variables.** The default authentication mode is bootstrap admin (local password, no external calls).

#### SMTP

If you configure SMTP (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`), the backend will connect to your mail relay to send user invitation emails.

**No SMTP traffic occurs unless you set these variables.** Without SMTP configured, invitation emails are logged to stdout instead.

#### Device Library Sync

The device equipment library sync mode is controlled by `RACKVIO_SYNC_MODE`:

| Value       | Outbound Traffic | Description                                                   |
| ----------- | ---------------- | ------------------------------------------------------------- |
| `airgapped` | None             | Default. Only accepts signed ZIP bundle uploads via the UI.   |
| `online`    | Yes              | Fetches device type catalog from `RACKVIO_LIBRARY_URL`.       |
| `both`      | Yes              | Both channels active.                                         |

**The default is `airgapped`.** No outbound traffic for library sync unless you change this setting.

## Docker Image Provenance

Rackvio Community Edition uses the following base images:

| Image                     | Source           | Purpose              |
| ------------------------- | ---------------- | -------------------- |
| `pgvector/pgvector:pg16`  | Docker Hub       | PostgreSQL database  |
| `redis:7-alpine`          | Docker Hub       | Cache and queue      |
| Custom (Dockerfile)       | Built from source| Backend and frontend |

All images are pulled only during initial build. In air-gapped deployments, images can be pre-loaded via `docker load` (see [INSTALL.md](INSTALL.md)).

## Verification

To verify zero outbound traffic in your environment:

```bash
# Monitor all outbound connections from the Rackvio containers
# (should show only inter-container traffic on the Docker bridge)
docker compose -f docker-compose.community.yml exec backend \
  ss -tunp 2>/dev/null || netstat -tunp

# Or use tcpdump on the host to monitor the Docker bridge
sudo tcpdump -i docker0 -n 'not (src net 172.16.0.0/12 and dst net 172.16.0.0/12)'
```

If the above captures show no packets, Rackvio is making no outbound connections.

## Changes to This Policy

This policy applies to Rackvio Community Edition as distributed. Any future features that introduce outbound connections will:

1. Be **opt-in only** (disabled by default).
2. Be documented in this policy before release.
3. Be controlled by an explicit environment variable.
4. Never be silently enabled via an upgrade.
