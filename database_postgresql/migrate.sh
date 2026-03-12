#!/bin/bash
set -euo pipefail

# PostgreSQL migration runner for this container.
#
# Contract:
# - Inputs:
#   - db_connection.txt must exist and contain a `psql postgresql://...` command.
#   - migrations live in ./migrations and are applied in lexicographic order by filename.
# - Outputs:
#   - Creates/updates tables in the target database.
#   - Records applied migrations in public.schema_migrations.
# - Errors:
#   - Exits non-zero if db_connection.txt is missing, connection fails, or any migration fails.
# - Side effects:
#   - Writes to the connected PostgreSQL database only.

MIGRATIONS_DIR="${MIGRATIONS_DIR:-./migrations}"
DB_CONN_FILE="${DB_CONN_FILE:-./db_connection.txt}"

log() {
  echo "[migrate] $1"
}

fail() {
  echo "[migrate][error] $1" >&2
  exit 1
}

if [ ! -f "${DB_CONN_FILE}" ]; then
  fail "Missing ${DB_CONN_FILE}. Run startup.sh first (it creates db_connection.txt)."
fi

PSQL_CMD="$(cat "${DB_CONN_FILE}" | tr -d '\n\r')"
if [ -z "${PSQL_CMD}" ]; then
  fail "${DB_CONN_FILE} is empty."
fi

if [ ! -d "${MIGRATIONS_DIR}" ]; then
  fail "Missing migrations directory: ${MIGRATIONS_DIR}"
fi

log "Using connection: ${PSQL_CMD} (from ${DB_CONN_FILE})"
log "Migrations dir: ${MIGRATIONS_DIR}"

# Ensure migration ledger exists.
${PSQL_CMD} -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS public.schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now());"

# Apply migrations in order.
shopt -s nullglob
MIGRATION_FILES=("${MIGRATIONS_DIR}"/*.sql)

if [ ${#MIGRATION_FILES[@]} -eq 0 ]; then
  log "No migration files found; nothing to do."
  exit 0
fi

for file in "${MIGRATION_FILES[@]}"; do
  version="$(basename "${file}")"

  already_applied="$(${PSQL_CMD} -tA -v ON_ERROR_STOP=1 -c "SELECT 1 FROM public.schema_migrations WHERE version='${version}' LIMIT 1;")"
  if [ "${already_applied}" = "1" ]; then
    log "Skip (already applied): ${version}"
    continue
  fi

  log "Applying: ${version}"
  # Use a single transaction for each migration to avoid partial application.
  ${PSQL_CMD} -v ON_ERROR_STOP=1 -c "BEGIN;"

  # Apply the migration file (SQL can contain multiple statements).
  ${PSQL_CMD} -v ON_ERROR_STOP=1 -f "${file}"

  ${PSQL_CMD} -v ON_ERROR_STOP=1 -c "INSERT INTO public.schema_migrations(version) VALUES ('${version}');"
  ${PSQL_CMD} -v ON_ERROR_STOP=1 -c "COMMIT;"

  log "Applied: ${version}"
done

log "All migrations complete."
