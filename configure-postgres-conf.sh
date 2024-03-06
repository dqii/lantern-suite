#!/bin/bash

POSTGRESQL_CONF_FILE="/var/lib/postgresql/data/postgresql.conf"
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

# Convert kilobytes to megabytes
shared_buffers_mb=$(echo "scale=0; $shared_buffers_kb / 1024" | bc)
postgresql_set_property "shared_buffers" "${shared_buffers_mb}MB"
postgresql_set_property "effective_cache_size" "${shared_buffers_mb}MB"
echo "Set shared_buffers and effective_cache_size to ${shared_buffers_mb}MB"
