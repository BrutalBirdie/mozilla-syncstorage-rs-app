#!/bin/bash

set -eu

# same queries as upstream tools/postgres/purge_ttl.py, which would need a Python runtime
# https://github.com/mozilla-services/syncstorage-rs/blob/master/tools/postgres/purge_ttl.py
echo "==> Purging expired batches and records"
PGPASSWORD="${CLOUDRON_POSTGRESQL_PASSWORD}" psql -v ON_ERROR_STOP=1 \
    -h "${CLOUDRON_POSTGRESQL_HOST}" -p "${CLOUDRON_POSTGRESQL_PORT}" -U "${CLOUDRON_POSTGRESQL_USERNAME}" -d "${CLOUDRON_POSTGRESQL_DATABASE}" <<'EOF'
DELETE FROM batches WHERE expiry < CURRENT_TIMESTAMP;
DELETE FROM bsos WHERE expiry < CURRENT_TIMESTAMP;
EOF
