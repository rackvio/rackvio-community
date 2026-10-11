# Rackvio Community Edition -- Installation Guide

This guide gets you from zero to a running Rackvio instance in a few minutes.

## System requirements

| Requirement       | Minimum             |
| ----------------- | ------------------- |
| Docker            | 24.0+               |
| Docker Compose    | v2 (bundled with Docker Desktop) |
| RAM               | 4 GB                |
| CPU               | 2 cores             |
| Disk              | 10 GB free          |
| Operating system  | Linux, macOS, or Windows (with WSL2) |

Rackvio runs entirely in Docker containers. Nothing else (Node.js, Python, PostgreSQL) needs to be
installed on the server.

## Install

```bash
# 1. Download the compose file and the settings template
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/rackvio/rackvio-community/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/rackvio/rackvio-community/main/.env.example

# 2. Create your settings file
cp .env.example .env
# Edit .env -- at minimum set:
#   PLATFORM_ADMIN_EMAIL=you@yourcompany.com
#   AUTH_SECRET=<your own random secret>   (generate it with: openssl rand -hex 32)
# and set the database passwords now (see "Database passwords" below).

# 3. Start Rackvio (pulls the prebuilt images)
docker compose up -d
```

The first start takes a minute or two while the images download and the database is prepared. Watch
it with `docker compose logs -f`.

If `AUTH_SECRET` or `PLATFORM_ADMIN_EMAIL` is missing, `docker compose up` stops with a message
saying which.

## Open Rackvio

Open `http://<your-server>:3000` in a browser on any computer that can reach the server — its name or
IP address, or `http://localhost:3000` on the server itself. The web app and the API share this one
port: the browser calls `/api` on the same address, and the web app passes those calls to the
backend inside the Docker network. The backend and the database publish no ports of their own.

- **A different port:** set `RACKVIO_PORT` in `.env` and run `docker compose up -d`.
- **Your own hostname and HTTPS:** put your own reverse proxy in front of port 3000 and forward
  everything (`/` and `/api`) to it. Pass the `Host` (or `X-Forwarded-Host`) and `X-Forwarded-Proto`
  headers, so that sign-in follows the address people use and its cookies are marked secure on
  HTTPS.
- **Links in emails:** set `RACKVIO_PUBLIC_URL` in `.env` to the address people open, for example
  `https://rackvio.example.com`. Rackvio puts it in invitation and password-reset links. Sign-in
  itself works at any address without it.

## Sign in for the first time

On the first start Rackvio creates the organization **Default** and an administrator account for
`PLATFORM_ADMIN_EMAIL`, and prints a temporary password in the backend log:

```bash
docker compose logs backend | grep -iA 1 "temporary password"
```

```
  =============================================
  Bootstrap admin created
  Email: you@yourcompany.com
  Temporary password: 1a2b3c4d5e6f7890
  Change this password after first login.
```

1. Open Rackvio, enter the email address, click **Continue**, enter the temporary password and
   click **Sign in**.
2. Choose a new password. Rackvio signs you out; sign in again with the new one.

A banner reminds you while you are signed in as this first (bootstrap) administrator.

### If you lose the temporary password

Print a password-reset link on the server and open it (it is valid for 15 minutes and works once):

```bash
docker compose exec backend rackvio admin reset-link you@yourcompany.com
```

Or set a new password directly; it asks for it twice:

```bash
docker compose exec backend rackvio admin reset-password you@yourcompany.com
```

## Settings

Every setting goes in `.env`, and every line in `.env` reaches Rackvio. After a change, run
`docker compose up -d`. `.env.example` lists them with comments. Keep comments on their own lines:
text after a value becomes part of the value.

### Required

| Setting | What it's for |
| --- | --- |
| `PLATFORM_ADMIN_EMAIL` | The email address of the first administrator account |
| `AUTH_SECRET` | A random secret that signs sign-ins and links, and protects two-factor secrets. Generate it with `openssl rand -hex 32`. The value in `.env.example` is only an example and must be replaced |

### Address, port and version

| Setting | Default | What it's for |
| --- | --- | --- |
| `RACKVIO_PUBLIC_URL` | `http://localhost:3000` | The address used in emailed and printed links |
| `RACKVIO_PORT` | `3000` | The port Rackvio listens on |
| `RACKVIO_VERSION` | `latest` | The release to run. Pin a version such as `1.2.2` to upgrade on your own schedule |

### Database passwords

| Setting | Default | What it's for |
| --- | --- | --- |
| `DB_PASS` | `devpassword` | The PostgreSQL administrator account |
| `APP_DB_PASS` | `devpassword` | The account Rackvio uses for everyday reads and writes |
| `MIGRATIONS_DB_PASS` | `devpassword` | The account Rackvio uses to update the database structure |

Set a different strong password for each one **before the first start**, for example with
`openssl rand -base64 24 | tr -d '=+/'`. The database accounts are created on the first start only;
to change a password later, see [Troubleshooting](#database-authentication-failed-after-changing-a-password).

### Email

Rackvio sends two kinds of email: invitations to new users, and password-reset links.

| Setting | Default | What it's for |
| --- | --- | --- |
| `SMTP_HOST` | (not set) | Your mail server. Email is off until this is set |
| `SMTP_PORT` | `587` | Its port |
| `SMTP_USE_TLS` | `true` | Upgrade the connection with STARTTLS. Servers that only accept TLS from the start (usually port 465) aren't supported |
| `SMTP_USERNAME` | (not set) | Sign-in name for the mail server, if it needs one |
| `SMTP_PASSWORD` | (not set) | Its password |
| `SMTP_FROM_EMAIL` | `noreply@rackvio.local` | The From address |

Without a mail server you can still invite people and reset passwords — see the next section.

### Invitations and password resets without email

An administrator can hand a link over directly:

- **Admin → Users**, on a pending invitation's row: **Copy invitation link**. The link is valid for
  72 hours and works once. Creating it replaces any earlier link for that invitation, including one
  already emailed.
- **Admin → Users**, on another user's row: **Create a password-reset link**. It is valid for
  15 minutes and works once; the user's current password keeps working until they use it.

Or print the same links on the server:

```bash
docker compose exec backend rackvio admin invite-link someone@example.com
docker compose exec backend rackvio admin reset-link someone@example.com
```

Each link is recorded in the audit log. Links are never written to the server logs. Printed links use
`RACKVIO_PUBLIC_URL`; the Users page uses that address too, or the address you are using if it isn't
set.

### Two-factor authentication and changing AUTH_SECRET

The key that protects two-factor secrets is derived from `AUTH_SECRET`. To change `AUTH_SECRET`
without breaking anyone's authenticator app:

1. Print the current key and add the last line it prints to `.env` as `MFA_ENCRYPTION_KEY=...`:

   ```bash
   docker compose exec backend rackvio admin mfa-print-key
   ```

2. Put the new `AUTH_SECRET` in `.env`.
3. Run `docker compose up -d --force-recreate backend frontend`. Everyone is signed out and signs in
   again.

If you skip step 1, two-factor users aren't locked out: each signs in with a recovery code and sets
up their authenticator app again.

### Floor-plan storage

Uploaded floor-plan drawings are kept on the `uploads` Docker volume, so they survive restarts and
upgrades. Back them up with the database (see [Back up and restore](#back-up-and-restore)).

To keep them in Amazon S3 or an S3-compatible service instead:

| Setting | What it's for |
| --- | --- |
| `STORAGE_BACKEND` | `local` (the default) or `s3` |
| `S3_BUCKET` | The bucket. Required with `s3` |
| `S3_REGION` | Defaults to `us-east-1` |
| `S3_ENDPOINT_URL` | For an S3-compatible service. Leave it unset for Amazon S3 |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Credentials, if the server has no other way to get them |

Copy the existing drawings before you switch: add the S3 settings to `.env` but leave
`STORAGE_BACKEND` unset, run `docker compose up -d`, then

```bash
docker compose exec -e STORAGE_BACKEND=s3 backend rackvio uploads migrate
```

When it has run cleanly, set `STORAGE_BACKEND=s3` in `.env` and run `docker compose up -d` again.

## Load demo data

To try Rackvio with an example colocation facility, run this on a new install, before you create any
sites:

```bash
docker compose run --rm --entrypoint python backend -m app.seed.demo_seed --org-name Default
```

It adds the data to **Default**, the organization your administrator account belongs to: one site
with two buildings and four rooms, 50 racks with roughly 150 to 200 devices, a power chain from the
utility feeds to the rack outlets, and an IP network with three subnets. If the organization already
has a site, the command changes nothing and says so.

> **Don't add `--reset`.** It deletes the organization it seeds, including its users, before seeding
> again. Without `--org-name Default` the command creates a separate organization that has no users,
> so nobody can sign in to see it.

## Import your assets

Use **Admin → Import** and **Download CSV Template**. Each equipment model and each rack must already
exist, with exactly the name in the file. There is no dry run: valid rows are saved when you click
**Upload and Import**, and **Download failed rows** gives you the rest with the reason.

## Upgrade

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

1. [Back up](#back-up-and-restore).
2. **The first time you upgrade to this compose file** (the one with an `uploads` volume), copy the
   floor-plan drawings out of the running backend before you replace `docker-compose.yml`; the old
   file kept them inside the container, and they go when it is replaced:

   ```bash
   docker compose cp backend:/app/uploads ./uploads-before-upgrade
   ```

   Then download the new `docker-compose.yml` and `.env.example` (see [Install](#install)), and add
   any new settings you want from `.env.example` to your `.env`. The API is now reached through port
   3000 at `/api`; port 8000 is no longer published.
3. Pull the new images and restart:

   ```bash
   docker compose pull
   docker compose up -d
   ```

   Rackvio updates the database structure on its own when it starts. If you copied drawings out in
   step 2, put them back:

   ```bash
   docker compose cp ./uploads-before-upgrade/. backend:/app/uploads
   ```

4. Refresh the device library, which is only loaded on the first start:

   ```bash
   docker compose run --rm --entrypoint python backend -m app.library.apply_seed
   ```

   It adds new device types and updates existing ones; it never removes any.

Database updates only go forward. To go back to the previous version, restore the backup from step 1
and run the previous images (`RACKVIO_VERSION`).

### What changes in 1.2.4

1.2.4 brings fixes and one small database update. `.env` and `docker-compose.yml` stay as they are.
From 1.2.3, back up (step 1), then pull the new images and restart (step 3); if you pin
`RACKVIO_VERSION` in `.env`, set it to `1.2.4` first. From 1.2.2, read
[What changes in 1.2.3](#what-changes-in-123) too. From 1.2.1 or earlier, follow every step and read
[What changes in 1.2.2](#what-changes-in-122) too.

- **Database update 0050** runs on its own when the backend starts, before it answers. It is
  additive: one column, in a table Community Edition doesn't use, becomes optional, and no data
  changes. Database updates only go forward: to go back to 1.2.3, restore the backup.
- **A saved change is saved.** When Rackvio answers that a change worked, the change is already in
  the database. Before, the answer could arrive a moment before the save finished, so a script that
  created something and used it at once (a floor, then a room on it) could be told it didn't exist.
- **CSV asset import checks `face` and `lifecycle_state`.** Case and spaces don't matter (`Front`,
  ` Installed `). An empty `face` is front and an empty `lifecycle_state` is installed. Any other
  value skips the row, with a reason naming the allowed values; before, it was stored as written and
  the asset showed on neither face of its rack. Assets imported earlier are not changed.
- **Custom fields of every type.** Install Asset no longer fails ("Error 422") for a model with a
  number or yes/no custom field, and Edit Asset shows and saves the model's custom fields.
- **No email to example addresses.** Rackvio sends nothing to example.com, example.net or
  example.org (or any name under them), or to an address ending `.example`, `.test`, `.invalid` or
  `.localhost`: mail there can never be delivered. The backend log names the skipped address, and in
  Admin > Users you copy the link instead. A test mailbox whose `SMTP_HOST` is exactly `mailhog` or
  `mailpit` still receives them.
- **Logs never contain tokens.** The backend no longer logs each outgoing HTTP request (the HTTP
  client libraries log only warnings and errors), its request log masks the value of any query
  parameter whose name looks like a secret (`token`, `key`, `secret`, `code`, `signature`,
  `password` are logged as `***`), and a device-library sync address is logged and shown without its
  user name, password or query.
- **`LOG_LEVEL` (optional).** The backend log now also carries Rackvio's own messages, with the time
  and level. To change how much it writes, add `LOG_LEVEL=WARNING` (or `DEBUG`, `ERROR`) to `.env`
  and run `docker compose up -d`; the default is `INFO`.
- **Screens.** On Capacity > Reconciliation the status badges stay on one line, the "Designed kW"
  explanation is a button you can reach with the keyboard, and the "data check" label is readable in
  the dark theme. The sign-in page's small links and the Install Asset form meet WCAG AA contrast.
  Admin > Aliases uses generic examples and, when you try to add a second source system, names the
  one you have; the asset import page links to it.

### What changes in 1.2.3

1.2.3 is a security update only. There is no functional change and no new setting: `.env` and
`docker-compose.yml` stay as they are. From 1.2.2, back up (step 1), then pull the new images and
restart (step 3); if you pin `RACKVIO_VERSION` in `.env`, set it to `1.2.3` first. From 1.2.1 or
earlier, follow every step and read [What changes in 1.2.2](#what-changes-in-122) too.

- **Security updates:** Next.js 15.5.27 and sharp 0.35.5 in the web app; pyasn1 0.6.4 and WeasyPrint
  70 in the backend. Each fixes published security advisories in the version 1.2.2 shipped.
- **Next.js's image optimiser is switched off.** Rackvio never used it, so nothing on screen changes;
  `/_next/image` now answers 404.

### What changes in 1.2.2

- **Floor-plan drawings** now live on their own `uploads` volume. The first time you upgrade to this
  compose file, copy them out before you replace `docker-compose.yml` (step 2 above).
- **One port.** The web app and the API share port 3000 (`RACKVIO_PORT`), with the API at `/api`;
  port 8000 is no longer published. Scripts that called `http://<your-server>:8000/...` now call
  `http://<your-server>:3000/api/...`.
- **Password-reset links** emailed in the 15 minutes before the upgrade stop working. Ask for a new
  one, or an administrator creates one in Admin > Users.
- **3D room view labels** now use a font that ships with Rackvio (Inter), so the 3D view no longer
  contacts cdn.jsdelivr.net and its labels show on servers without internet access. Characters Inter
  does not include (for example Chinese, Japanese, Korean, Arabic or emoji in rack names) show as
  boxes in the 3D view. The rest of the app is unchanged.

## Back up and restore

Back up three things.

**The database:**

```bash
docker compose exec -T postgres pg_dump -U postgres -Fc rackvio > rackvio-$(date +%Y%m%d).dump
```

**Uploaded floor-plan drawings:**

```bash
docker compose cp backend:/app/uploads ./uploads-$(date +%Y%m%d)
```

**Your `.env` file.** Two-factor secrets can only be read with the `AUTH_SECRET` (or
`MFA_ENCRYPTION_KEY`) that was in use when they were saved.

To restore, stop Rackvio, load the backup, and start it again, with the same Rackvio version you
backed up from:

```bash
docker compose stop backend frontend
docker compose exec -T postgres pg_restore -U postgres -d rackvio --clean --if-exists < rackvio-YYYYMMDD.dump
docker compose cp ./uploads-YYYYMMDD/. backend:/app/uploads
docker compose start backend frontend
```

## Run without internet access

Rackvio makes no outbound connections unless you configure them (see the
[Network Traffic Policy](NETWORK-TRAFFIC-POLICY.md)). To install on a server with no internet access:

1. On a computer with internet access, in the folder with your `docker-compose.yml` and `.env`:

   ```bash
   docker compose pull
   docker save ghcr.io/rackvio/rackvio-backend:latest ghcr.io/rackvio/rackvio-frontend:latest \
     pgvector/pgvector:pg16 redis:7-alpine | gzip > rackvio-images.tar.gz
   ```

   (Use your `RACKVIO_VERSION` instead of `latest` if you pinned one.)
2. Copy `rackvio-images.tar.gz`, `docker-compose.yml` and `.env` to the server.
3. Load the images and start Rackvio:

   ```bash
   docker load < rackvio-images.tar.gz
   docker compose up -d
   ```

The device library is inside the backend image, so it needs no download.

## Recovery commands

These work directly on the database, for when you can't get in through the browser. Run them on the
server, in the folder with your `docker-compose.yml`, with `docker compose exec backend` in front.
Anyone who can run them already has full access to the server, so they add no new risk.

| Command | What it does |
| --- | --- |
| `rackvio admin reset-link <email>` | Prints a password-reset link (15 minutes, works once) |
| `rackvio admin invite-link <email>` | Prints a new link for a pending invitation (72 hours, works once) |
| `rackvio admin reset-password <email>` | Sets a new password for a user. Asks for it twice |
| `rackvio admin promote-bootstrap <email>` | Marks a user as the bootstrap administrator |
| `rackvio admin mfa-disable-requirement Default` | Turns off **Require two-factor authentication** for the organization. Users keep their authenticators |
| `rackvio admin mfa-print-key` | Prints the key that protects two-factor secrets (see above) |
| `rackvio uploads migrate` | Copies floor-plan drawings to S3 (see above) |

`Default` is the name of your organization. `rackvio admin --help` lists a few more commands, for
features that Community Edition doesn't include.

## What Community Edition includes

Community Edition has the core of Rackvio with no limits on assets or users. Features that aren't in
it aren't switched off: their code isn't in the images at all, and their addresses answer 404. For
example:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/admin/sso/providers
# 404
```

See [rackvio.com](https://rackvio.com) for the Cloud plans.

## Troubleshooting

### Port 3000 is already in use

Set `RACKVIO_PORT` in `.env` to a free port and run `docker compose up -d`.

### I can't sign in as the bootstrap administrator

- The temporary password is printed only on the first start, when there are no users yet. If you
  can't find it, [print a reset link](#if-you-lose-the-temporary-password).
- Use the email address that was in `PLATFORM_ADMIN_EMAIL` on the first start. Changing it later
  doesn't create a new account.

### Signing in loops back to the sign-in page behind my reverse proxy

Your proxy isn't passing the original address. Forward the `Host` (or `X-Forwarded-Host`) and
`X-Forwarded-Proto` headers.

### Database authentication failed after changing a password

The database accounts keep the passwords from the first start. Either update them to match `.env`:

```bash
docker compose exec postgres psql -U postgres -c "ALTER ROLE rackvio_app WITH PASSWORD 'new_app_password';"
docker compose exec postgres psql -U postgres -c "ALTER ROLE rackvio_migrations WITH PASSWORD 'new_migrations_password';"
```

or start again with an empty database, which **deletes all your data** (see below).

### The backend keeps restarting

```bash
docker compose ps
docker compose logs backend
```

The usual causes are PostgreSQL still starting (wait 30 seconds and look again), or database
passwords that no longer match (see above).

### Start again from nothing

```bash
docker compose down -v
docker compose up -d
```

This deletes the database and every Docker volume of this install, including uploaded drawings. Use
it only as a last resort.
