set -euo pipefail

function run_pgbouncer() {
  cd /tmp
  /opt/configure-pgbouncer.sh
  pgbouncer /tmp/pgbouncer.ini 2>&1 | sed -u -e 's/^/[PGBOUCNER]: /'
  echo "Running pgbouncer in the background"
}

run_pgbouncer
