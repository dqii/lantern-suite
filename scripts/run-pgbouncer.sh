set -euo pipefail

cd /tmp
/opt/configure-pgbouncer.sh
rm -rf /tmp/pgbouncer.pid || true
pgbouncer /tmp/pgbouncer.ini 2>&1 | sed -u -e 's/^/[PGBOUCNER]: /'
echo "Running pgbouncer in the background"
