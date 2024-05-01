#!/bin/bash

set -euo pipefail

PG_SOCKET_DIR=/var/run/postgresql
POSTGRESQL_PGHBA_FILE=/var/lib/postgresql/data/pg_hba.conf
POSTGRESQL_PORT_NUMBER=5432
POSTGRESQL_INIT_MAX_TIMEOUT=20
cd $PG_SOCKET_DIR

check_cmd="pg_isready"
ready_counter=$POSTGRESQL_INIT_MAX_TIMEOUT

generate_random_string() {
    local count="32"
    local filter
    local result
    local filter='a-zA-Z0-9:@.,/+!='
    result="$(head -n "$((count + 10))" /dev/urandom | tr -dc "$filter" | head -c "$count")"
    echo "$result"
}

while ! "${check_cmd[@]}" -h $PG_SOCKET_DIR -p $POSTGRESQL_PORT_NUMBER ; do
    sleep 1
    ready_counter=$((ready_counter - 1))
    if ((ready_counter <= 0)); then
        error "PostgreSQL is not ready after $POSTGRESQL_INIT_MAX_TIMEOUT seconds"
        exit 1
    fi
done

pg_bouncer_password=$(generate_random_string -t alphanumeric+special)
# Create pgbouncer user for authentication
psql -U postgres -h $PG_SOCKET_DIR -p $POSTGRESQL_PORT_NUMBER postgres -t  <<SQL
    DO
    \$do\$
    BEGIN
       IF EXISTS (
          SELECT FROM pg_catalog.pg_roles
          WHERE  rolname = '_pgbouncer') THEN
          RAISE NOTICE 'Role "_pgbouncer" already exists. Skipping.';
          GRANT SELECT ON pg_shadow TO _pgbouncer;
          GRANT USAGE ON SCHEMA public TO _pgbouncer;
       ELSE
          CREATE ROLE _pgbouncer LOGIN PASSWORD '${pg_bouncer_password}';
          GRANT USAGE ON SCHEMA public TO _pgbouncer;
          GRANT SELECT ON pg_shadow TO _pgbouncer;
       END IF;
    END
    \$do\$;
SQL

psql -Atq -U postgres -d postgres -c "SELECT concat('\"', usename, '\" \"', passwd, '\"') FROM pg_shadow WHERE usename='_pgbouncer'" > userlist.txt

cat <<EOF > pgbouncer.ini
[pgbouncer]
# Connection settings
listen_addr = *
listen_port = 6432
auth_type = hba
auth_user = _pgbouncer
auth_hba_file = $POSTGRESQL_PGHBA_FILE
auth_file = userlist.txt
unix_socket_dir = $PG_SOCKET_DIR
auth_query = SELECT usename, passwd FROM pg_shadow WHERE usename=\$1
auth_dbname = postgres

pidfile = pgbouncer.pid
admin_users = postgres
stats_users = postgres
pool_mode = session
ignore_startup_parameters = extra_float_digits
max_client_conn = 2000
default_pool_size = 80
reserve_pool_size = 5
reserve_pool_timeout = 3
server_lifetime = 300
server_idle_timeout = 120
server_connect_timeout = 5
server_login_retry = 1
query_wait_timeout = 60
client_login_timeout = 60
EOF

cat <<EOF >> pgbouncer.ini
[databases]
# connect to postgres via domain socket
* = host=$PG_SOCKET_DIR port=$POSTGRESQL_PORT_NUMBER
EOF
