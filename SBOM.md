# Rackvio Community Edition -- Software Bill of Materials (SBOM)

## Overview

Rackvio publishes a Software Bill of Materials (SBOM) in CycloneDX JSON format for both the backend (Python) and frontend (Node.js) components. The SBOM provides a complete inventory of all third-party dependencies, enabling:

- **Vulnerability scanning** against CVE databases (NVD, OSV, GitHub Advisory)
- **License compliance** auditing for open-source obligations
- **Supply chain transparency** for enterprise procurement review

## SBOM Format

| Field    | Value                          |
| -------- | ------------------------------ |
| Standard | CycloneDX v1.5                 |
| Format   | JSON                           |
| Files    | `sbom-backend.json`, `sbom-frontend.json` |

## Generating SBOMs

### Prerequisites

The generation tools are not included in the Rackvio runtime containers. Install them in your local environment or CI pipeline.

### Backend SBOM (Python)

The backend SBOM covers all Python packages in the application:

```bash
# Install the CycloneDX Python tool
pip install cyclonedx-bom

# Generate SBOM from the installed packages (recommended -- captures exact versions)
# Run inside the backend container or a venv with backend deps installed:
cyclonedx-py environment -o sbom-backend.json --output-format json

# Alternative: generate from pyproject.toml (if no venv available)
cyclonedx-py requirements backend/requirements.txt -o sbom-backend.json --format json 2>/dev/null \
  || cyclonedx-py environment -o sbom-backend.json --output-format json
```

### Frontend SBOM (Node.js)

The frontend SBOM covers all npm packages:

```bash
# Generate SBOM using the CycloneDX npm plugin (npx, no global install needed)
cd frontend
npx @cyclonedx/cyclonedx-npm --output-file ../sbom-frontend.json .
cd ..
```

### Generate Both at Once

```bash
#!/usr/bin/env bash
# generate-sbom.sh -- Generate CycloneDX SBOMs for Rackvio
set -euo pipefail

echo "Generating backend SBOM (Python)..."
pip install --quiet cyclonedx-bom
cyclonedx-py environment -o sbom-backend.json --output-format json
echo "  -> sbom-backend.json"

echo "Generating frontend SBOM (Node.js)..."
cd frontend
npx --yes @cyclonedx/cyclonedx-npm --output-file ../sbom-frontend.json .
cd ..
echo "  -> sbom-frontend.json"

echo "SBOM generation complete."
```

## What the SBOM Covers

### Backend (`sbom-backend.json`)

| Category            | Examples                                          |
| ------------------- | ------------------------------------------------- |
| Web framework       | FastAPI, Uvicorn, Starlette                       |
| Database            | SQLAlchemy, asyncpg, Alembic                      |
| Auth                | python-jose, passlib, bcrypt                      |
| Validation          | Pydantic, pydantic-settings                       |
| Task queue          | Redis (aioredis)                                  |
| Utilities           | python-multipart, python-dotenv, httpx            |

### Frontend (`sbom-frontend.json`)

| Category            | Examples                                          |
| ------------------- | ------------------------------------------------- |
| Framework           | Next.js, React, React DOM                         |
| UI components       | Radix UI, Tailwind CSS, Lucide icons              |
| State management    | React Query (TanStack)                            |
| Auth                | NextAuth.js (Auth.js)                             |
| Visualization       | Three.js (3D renderer), Recharts                  |
| Utilities           | date-fns, clsx, zod                               |

## SBOM in Release Artifacts

For each tagged release, the SBOM files are:

1. Generated in CI during the release build.
2. Attached to the GitHub Release as downloadable assets.
3. Embedded in the Docker image labels (OCI annotations).

To extract the SBOM from a running container:

```bash
# Check OCI labels for SBOM reference
docker inspect rackvio-community-backend | jq '.[0].Config.Labels'
```

## Scanning the SBOM

### Using Trivy (recommended)

```bash
# Scan the backend SBOM for known vulnerabilities
trivy sbom sbom-backend.json

# Scan the frontend SBOM
trivy sbom sbom-frontend.json
```

### Using Grype

```bash
grype sbom:sbom-backend.json
grype sbom:sbom-frontend.json
```

### Using OSV-Scanner

```bash
osv-scanner --sbom=sbom-backend.json
osv-scanner --sbom=sbom-frontend.json
```

## Updating the SBOM

The SBOM should be regenerated whenever dependencies change:

- After running `pip install` or updating `pyproject.toml` (backend)
- After running `npm install` or updating `package.json` (frontend)
- Before every tagged release

CI automation ensures the SBOM in release artifacts always matches the shipped code.
