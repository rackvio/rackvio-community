#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER rackvio_app WITH PASSWORD '${APP_DB_PASS}';
  CREATE USER rackvio_migrations WITH PASSWORD '${MIGRATIONS_DB_PASS}' CREATEROLE;

  ALTER DATABASE rackvio OWNER TO rackvio_migrations;
  GRANT ALL PRIVILEGES ON DATABASE rackvio TO rackvio_migrations;
  GRANT CONNECT ON DATABASE rackvio TO rackvio_app;

  \c rackvio

  ALTER DEFAULT PRIVILEGES FOR ROLE rackvio_migrations
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO rackvio_app;

  ALTER DEFAULT PRIVILEGES FOR ROLE rackvio_migrations
    GRANT USAGE, SELECT ON SEQUENCES TO rackvio_app;

  GRANT USAGE ON SCHEMA public TO rackvio_app;
EOSQL
