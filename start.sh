#!/bin/bash

set -eu

if [[ ! -f /app/data/env.sh ]]; then
    echo "==> Copying default configuration"
    cp /app/pkg/env.sh.template /app/data/env.sh
fi

if [[ ! -f /app/data/.secrets.sh ]]; then
    echo "==> Generating secrets"
    cat > /app/data/.secrets.sh <<EOF
export SYNC_MASTER_SECRET=$(openssl rand -hex 32)
export SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET=$(openssl rand -hex 32)
EOF
    chmod 600 /app/data/.secrets.sh
fi

chown -R cloudron:cloudron /app/data

export SYNC_HOST=0.0.0.0
export SYNC_PORT=8000
# the postgresql addon is shared by all apps, upstream default is 10 per pool
export SYNC_SYNCSTORAGE__DATABASE_POOL_MAX_SIZE=5
export SYNC_TOKENSERVER__DATABASE_POOL_MAX_SIZE=5

source /app/data/env.sh
source /app/data/.secrets.sh

export SYNC_SYNCSTORAGE__DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
export SYNC_TOKENSERVER__DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
export SYNC_TOKENSERVER__ENABLED=true
export SYNC_TOKENSERVER__RUN_MIGRATIONS=true
export SYNC_TOKENSERVER__NODE_TYPE=postgres
export SYNC_TOKENSERVER__INIT_NODE_URL="${CLOUDRON_APP_ORIGIN}"

# init_node_url only inserts, so after a domain change existing users would keep the old node URL
PGPASSWORD="${CLOUDRON_POSTGRESQL_PASSWORD}" psql -q -v ON_ERROR_STOP=1 -v node="${CLOUDRON_APP_ORIGIN}" \
    -h "${CLOUDRON_POSTGRESQL_HOST}" -p "${CLOUDRON_POSTGRESQL_PORT}" -U "${CLOUDRON_POSTGRESQL_USERNAME}" -d "${CLOUDRON_POSTGRESQL_DATABASE}" <<'EOF'
SELECT to_regclass('public.nodes') IS NOT NULL AS has_nodes \gset
\if :has_nodes
UPDATE nodes SET node = :'node' WHERE node <> :'node';
\endif
EOF

echo "==> Starting syncserver"
exec gosu cloudron:cloudron /app/code/syncserver
