set -euo pipefail

PG_SOCKET_DIR=/var/run/postgresql
cd $PG_SOCKET_DIR
/opt/configure-pgbouncer.sh
rm -rf $PG_SOCKET_DIR/pgbouncer.pid || true
pgbouncer $PG_SOCKET_DIR/pgbouncer.ini 2>&1 | sed -u -e 's/^/[PGBOUCNER]: /'
echo "Running pgbouncer in the background"
