#!/bin/bash

ready_counter=20
while ! pg_isready; do
    sleep 1
    ready_counter=$((ready_counter - 1))
    if ((ready_counter <= 0)); then
        echo "PostgreSQL is not ready after 20 seconds"
        exit 1
    fi
done

cd /tmp
psql -Atq -U postgres -d postgres -c "SELECT concat('\"', usename, '\" \"', passwd, '\"') FROM pg_shadow" > userlist.txt

cat <<EOF > pgbouncer.ini
[databases]
# connect to postgres via domain socket
* = host=/var/run/postgresql/ port=5432

[pgbouncer]
# Connection settings
listen_addr = *
listen_port = 6432
auth_type = hba
auth_user = postgres
auth_file = userlist.txt
auth_hba_file = /var/lib/postgresql/data/pg_hba.conf
unix_socket_dir = /var/run/postgresql
pidfile = pgbouncer.pid
admin_users = postgres
stats_users = postgres
pool_mode = session
ignore_startup_parameters = extra_float_digits
max_client_conn = 2000
default_pool_size = 10
server_lifetime = 300
server_idle_timeout = 120
server_connect_timeout = 5
server_login_retry = 1
query_wait_timeout = 60
client_login_timeout = 60
EOF

echo "Done configuring pgbouncer"
