#!/bin/bash
set -euo pipefail

POSTGRESQL_CONF_FILE="/var/lib/postgresql/data/postgresql.conf"

########################
# Update the shared_preload_libraries configuration
# Globals:
#   POSTGRESQL_*
# Arguments:
#   $1 - library to add
#   $2 - Path to configuration file (default: $POSTGRESQL_CONF_FILE)
# Returns:
#   None
#########################
postgresql_update_shared_preload_libraries() {
    local -r library="${1:?missing library}"
    local -r conf_file="${2:-$POSTGRESQL_CONF_FILE}"
    local libraries

    if grep -qE "^shared_preload_libraries" "$conf_file"; then
        libraries=$(sed -E "s/^shared_preload_libraries\s*=\s*'(.*)'/\1/" "$conf_file")
        if [[ " $libraries " != *" $library "* ]]; then
            libraries="$libraries, $library"
            replace_in_file "$conf_file" "^shared_preload_libraries\s*=.*" "shared_preload_libraries = '$libraries'" false
        fi
    else
        echo "shared_preload_libraries = '$library'" >> "$conf_file"
    fi
}

########################
# Replace a regex-matching string in a file
# Arguments:
#   $1 - filename
#   $2 - match regex
#   $3 - substitute regex
#   $4 - use POSIX regex. Default: true
# Returns:
#   None
#########################
replace_in_file() {
    local filename="${1:?filename is required}"
    local match_regex="${2:?match regex is required}"
    local substitute_regex="${3:?substitute regex is required}"
    local posix_regex=${4:-true}

    local result

    # We should avoid using 'sed in-place' substitutions
    # 1) They are not compatible with files mounted from ConfigMap(s)
    # 2) We found incompatibility issues with Debian10 and "in-place" substitutions
    local -r del=$'\001' # Use a non-printable character as a 'sed' delimiter to avoid issues
    if [[ $posix_regex = true ]]; then
        result="$(sed -E "s${del}${match_regex}${del}${substitute_regex}${del}g" "$filename")"
    else
        result="$(sed "s${del}${match_regex}${del}${substitute_regex}${del}g" "$filename")"
    fi
    echo "$result" > "$filename"
}

########################
# Change a PostgreSQL configuration file by setting a property
# Globals:
#   POSTGRESQL_*
# Arguments:
#   $1 - property
#   $2 - value
#   $3 - Path to configuration file (default: $POSTGRESQL_CONF_FILE)
# Returns:
#   None
#########################
postgresql_set_property() {
    local -r property="${1:?missing property}"
    local -r value="${2:?missing value}"
    local -r conf_file="${3:-$POSTGRESQL_CONF_FILE}"
    local psql_conf
    if grep -qE "^#*\s*${property}" "$conf_file" >/dev/null; then
        replace_in_file "$conf_file" "^#*\s*${property}\s*=.*" "${property} = '${value}'" false
    else
        echo "${property} = '${value}'" >>"$conf_file"
    fi
}

# Get the total amount of RAM in kilobytes
total_ram=$(free -tk | awk 'NR == 2 {print $2}')

# Calculate 80% of the total RAM in kilobytes
shared_buffers_kb=$(echo "$total_ram * 0.80" | bc)
# Calculate 2% of the total RAM in kilobytes
work_mem_kb=$(echo "$total_ram * 0.02" | bc)

# Convert kilobytes to megabytes
shared_buffers_mb=$(echo "scale=0; $shared_buffers_kb / 1024" | bc)
work_mem_mb=$(echo "scale=0; $work_mem_kb / 1024" | bc)
postgresql_set_property "shared_buffers" "${shared_buffers_mb}MB"
postgresql_set_property "effective_cache_size" "${shared_buffers_mb}MB"
if [ "$work_mem_mb" -gt "64" ]; then
  postgresql_set_property "work_mem" "${work_mem_mb}MB"
  echo "Set work_mem to ${work_mem_mb}MB"
fi
echo "Set shared_buffers and effective_cache_size to ${shared_buffers_mb}MB"

# Enable pg_cron
postgresql_update_shared_preload_libraries "pg_cron"
