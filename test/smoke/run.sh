#!/bin/bash
# Smoke test without a Cloudron server: read-only rootfs and Postgres.
# Usage: test/smoke/run.sh   (needs Docker)  IMAGE=<tag> skips the build, KEEP=1 keeps the containers

set -eu

cd "$(dirname "$0")"
readonly root=$(cd ../.. && pwd)
readonly img=${IMAGE:-syncstorage:smoke}
readonly net=sssmoke
readonly app=sssmoke-app
readonly db=sssmoke-db
readonly url=http://127.0.0.1:18000
failures=0

cleanup() {
    [[ -n "${ARTIFACTS:-}" ]] && { mkdir -p "${ARTIFACTS}"; docker logs "${app}" > "${ARTIFACTS}/app.log" 2>&1 || true; }
    [[ -n "${KEEP:-}" ]] && return
    docker rm -f "${app}" "${db}" >/dev/null 2>&1 || true
    docker volume rm sssmoke-data >/dev/null 2>&1 || true
    docker network rm "${net}" >/dev/null 2>&1 || true
}
cleanup
trap cleanup EXIT

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1 :: $2"; failures=$((failures + 1)); }
expect() { if [[ "$3" =~ $2 ]]; then pass "$1"; else fail "$1" "${3:0:300}"; fi; }

wait_for() { # wait_for <seconds> <command...>
    local deadline=$((SECONDS + $1)); shift
    until "$@" >/dev/null 2>&1; do
        (( SECONDS > deadline )) && return 1
        sleep 2
    done
}

psql_db() { docker exec "${db}" psql -U user -d db -tAc "$1"; }

start_app() { # start_app <origin>
    docker rm -f "${app}" >/dev/null 2>&1 || true
    docker run -d --name "${app}" --network "${net}" --read-only --tmpfs /run:exec --tmpfs /tmp:exec -v sssmoke-data:/app/data -m 256m -p 127.0.0.1:18000:8000 \
        -e CLOUDRON_APP_ORIGIN="$1" \
        -e CLOUDRON_POSTGRESQL_URL="postgres://user:pass@${db}:5432/db" \
        -e CLOUDRON_POSTGRESQL_HOST="${db}" -e CLOUDRON_POSTGRESQL_PORT=5432 -e CLOUDRON_POSTGRESQL_DATABASE=db -e CLOUDRON_POSTGRESQL_USERNAME=user -e CLOUDRON_POSTGRESQL_PASSWORD=pass \
        "${img}" >/dev/null
    wait_for 60 curl -sf "${url}/__heartbeat__"
}

[[ -z "${IMAGE:-}" ]] && docker build -t "${img}" "${root}"

docker network create "${net}" >/dev/null
docker run -d --name "${db}" --network "${net}" -e POSTGRES_DB=db -e POSTGRES_USER=user -e POSTGRES_PASSWORD=pass postgres:18-alpine >/dev/null
wait_for 60 docker exec "${db}" pg_isready -U user -d db

if ! start_app https://sync.example.com; then
    fail "health" "app did not become healthy"
    exit 1
fi
pass "health"

expect "heartbeat" '"database":"Ok"' "$(curl -s ${url}/__heartbeat__)"
expect "version" '"version": *"[0-9]+\.[0-9]+\.[0-9]+"' "$(curl -s ${url}/__version__)"
expect "storage tables" "^t$" "$(psql_db "SELECT to_regclass('public.bsos') IS NOT NULL")"
expect "node registered" "^https://sync.example.com$" "$(psql_db "SELECT node FROM nodes")"
expect "token needs auth" "^401$" "$(curl -s -o /dev/null -w '%{http_code}' ${url}/1.0/sync/1.5)"
expect "storage needs auth" "^401$" "$(curl -s -o /dev/null -w '%{http_code}' ${url}/1.5/1/info/collections)"

secret=$(docker exec "${app}" cat /app/data/.secrets.sh)

if start_app https://moved.example.com; then pass "restart"; else fail "restart" "app did not become healthy"; fi
expect "node follows domain change" "^https://moved.example.com$" "$(psql_db "SELECT string_agg(node, ',') FROM nodes")"
expect "secrets kept" "^${secret}$" "$(docker exec "${app}" cat /app/data/.secrets.sh)"

psql_db "INSERT INTO user_collections (user_id, collection_id, modified) VALUES (1, 1, now());
    INSERT INTO bsos (user_id, collection_id, bso_id, payload, modified, expiry) VALUES (1, 1, 'old', '', now(), now() - interval '1 day'), (1, 1, 'new', '', now(), now() + interval '1 day');" >/dev/null
docker exec -e CLOUDRON_POSTGRESQL_HOST="${db}" -e CLOUDRON_POSTGRESQL_PORT=5432 -e CLOUDRON_POSTGRESQL_DATABASE=db -e CLOUDRON_POSTGRESQL_USERNAME=user -e CLOUDRON_POSTGRESQL_PASSWORD=pass \
    "${app}" /app/pkg/purge.sh >/dev/null
expect "purge removes expired only" "^new$" "$(psql_db "SELECT string_agg(bso_id, ',') FROM bsos")"

echo "==> ${failures} failures"
exit $(( failures > 0 ))
