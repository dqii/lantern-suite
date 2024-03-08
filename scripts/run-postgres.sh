set -euo pipefail
. /usr/local/bin/docker-ensure-initdb.sh
. /usr/local/bin/docker-entrypoint.sh

bash /opt/run-pgbouncer.sh &
. /opt/configure-postgres.sh
postgres
