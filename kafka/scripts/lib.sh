#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Constants
RESET='\033[0m'
RED='\033[38;5;1m'
GREEN='\033[38;5;2m'
YELLOW='\033[38;5;3m'
MAGENTA='\033[38;5;5m'
CYAN='\033[38;5;6m'

stderr_print() {
  printf "%b\\n" "${*}" >&2
}

log() {
  stderr_print "${CYAN}${MODULE:-} ${MAGENTA}$(date "+%T.%2N ")${RESET}${*}"
}

info() {
    local msg_color="$GREEN"
    log "${msg_color}INFO ${RESET} ==> ${*}"
}

warn() {
    local msg_color="$YELLOW"
    log "${msg_color}WARN ${RESET} ==> ${*}"
}

error() {
    local msg_color="$RED"
    log "${msg_color}ERROR${RESET} ==> ${*}"
}

debug() {
    local msg_color="$MAGENTA"
    # comparison is performed without regard to the case of alphabetic characters
    shopt -s nocasematch
    local debug_bool="${SCRIPT_DEBUG_ENABLED:-false}"
    if [[ "$debug_bool" = 1 || "$debug_bool" =~ ^(yes|true)$ ]]; then
        log "${msg_color}DEBUG${RESET} ==> ${*}"
    fi
}

# Indent a string
# Arguments:
#   $1 - string
#   $2 - number of indentation characters (default: 4)
#   $3 - indentation character (default: " ")
indent() {
    local string="${1:-}"
    local num="${2:?missing num}"
    local char="${3:-" "}"
    # Build the indentation unit string
    local indent_unit=""
    for ((i = 0; i < num; i++)); do
        indent_unit="${indent_unit}${char}"
    done
    # shellcheck disable=SC2001
    # Complex regex, see https://github.com/koalaman/shellcheck/wiki/SC2001#exceptions
    echo "$string" | sed "s/^/${indent_unit}/"
}

to_env_key() {
    local input="$1"
    # Encode in the correct order: _ → __, - → ___, . → _
    input="${input//_/__}"
    input="${input//-/___}"
    input="${input//./_}"
    echo "KAFKA_${input^^}"
}

from_env_key() {
    local input="$1"
    local without_prefix="${input#KAFKA_}"

    # Decode in reverse-safe order using temporary tokens
    without_prefix="${without_prefix//___/#DASH#}"
    without_prefix="${without_prefix//__/#UNDERSCORE#}"
    without_prefix="${without_prefix//_/\.}"
    without_prefix="${without_prefix//#UNDERSCORE#/_}"
    without_prefix="${without_prefix//#DASH#/-}"
    echo "${without_prefix,,}"
}

default_common_envs() {
  export KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=${KAFKA_LISTENER_SECURITY_PROTOCOL_MAP:-CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL}
  export KAFKA_NUM_NETWORK_THREADS=${KAFKA_NUM_NETWORK_THREADS:-3}
  export KAFKA_NUM_IO_THREADS=${KAFKA_NUM_IO_THREADS:-8}
  export KAFKA_SOCKET_SEND_BUFFER_BYTES=${KAFKA_SOCKET_SEND_BUFFER_BYTES:-102400}
  export KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=${KAFKA_SOCKET_RECEIVE_BUFFER_BYTES:-102400}
  export KAFKA_SOCKET_REQUEST_MAX_BYTES=${KAFKA_SOCKET_REQUEST_MAX_BYTES:-104857600}
  export KAFKA_LOG_DIRS=${KAFKA_LOG_DIRS:-/var/log/kafka}
  export KAFKA_NUM_PARTITIONS=${KAFKA_NUM_PARTITIONS:-1}
  export KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR=${KAFKA_NUM_RECOVERY_THREADS_PER_DATA_DIR:-1}
  export KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=${KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR:-1}
  export KAFKA_SHARE_COORDINATOR_STATE_TOPIC_REPLICATION_FACTOR=${KAFKA_SHARE_COORDINATOR_STATE_TOPIC_REPLICATION_FACTOR:-1}
  export KAFKA_SHARE_COORDINATOR_STATE_TOPIC_MIN_ISR=${KAFKA_SHARE_COORDINATOR_STATE_TOPIC_MIN_ISR:-1}
  export KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=${KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR:-1}
  export KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=${KAFKA_TRANSACTION_STATE_LOG_MIN_ISR:-1}
  export KAFKA_LOG_RETENTION_HOURS=${KAFKA_LOG_RETENTION_HOURS:-168}
  export KAFKA_LOG_SEGMENT_BYTES=${KAFKA_LOG_SEGMENT_BYTES:-1073741824}
  export KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS=${KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS:-300000}
}

default_combined_envs() {
  export KAFKA_PROCESS_ROLES=${KAFKA_PROCESS_ROLES:-broker,controller}
  export KAFKA_NODE_ID=${KAFKA_NODE_ID:-0}
  export KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS=${KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS:-localhost:9093}
  export KAFKA_LISTENERS=${KAFKA_LISTENERS:-PLAINTEXT://:9092,CONTROLLER://:9093}
  export KAFKA_INTER_BROKER_LISTENER_NAME=${KAFKA_INTER_BROKER_LISTENER_NAME:-PLAINTEXT}
  export KAFKA_ADVERTISED_LISTENERS=${KAFKA_ADVERTISED_LISTENERS:-PLAINTEXT://localhost:9092,CONTROLLER://localhost:9093}
  export KAFKA_CONTROLLER_LISTENER_NAMES=${KAFKA_CONTROLLER_LISTENER_NAMES:-CONTROLLER}
  export KAFKA_CONTROLLER_QUORUM_VOTERS=${KAFKA_CONTROLLER_QUORUM_VOTERS:-0@localhost:9093}
  default_common_envs
}

default_broker_envs() {
  export KAFKA_PROCESS_ROLES=${KAFKA_PROCESS_ROLES:-broker}
  export KAFKA_NODE_ID=${KAFKA_NODE_ID:-0}
  export KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS=${KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS:-localhost:9093}
  export KAFKA_LISTENERS=${KAFKA_LISTENERS:-PLAINTEXT://:9092}
  export KAFKA_INTER_BROKER_LISTENER_NAME=${KAFKA_INTER_BROKER_LISTENER_NAME:-PLAINTEXT}
  export KAFKA_ADVERTISED_LISTENERS=${KAFKA_ADVERTISED_LISTENERS:-PLAINTEXT://localhost:9092}
  export KAFKA_CONTROLLER_LISTENER_NAMES=${KAFKA_CONTROLLER_LISTENER_NAMES:-CONTROLLER}
  export KAFKA_CONTROLLER_QUORUM_VOTERS=${KAFKA_CONTROLLER_QUORUM_VOTERS:-1000@localhost:9093}
  default_common_envs
}

default_controller_envs() {
  export KAFKA_PROCESS_ROLES=${KAFKA_PROCESS_ROLES:-controller}
  export KAFKA_NODE_ID=${KAFKA_NODE_ID:-1000}
  export KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS=${KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS:-localhost:9093}
  export KAFKA_LISTENERS=${KAFKA_LISTENERS:-PLAINTEXT://:9093}
  export KAFKA_ADVERTISED_LISTENERS=${KAFKA_ADVERTISED_LISTENERS:-PLAINTEXT://localhost:9093}
  export KAFKA_CONTROLLER_LISTENER_NAMES=${KAFKA_CONTROLLER_LISTENER_NAMES:-CONTROLLER}
  export KAFKA_CONTROLLER_QUORUM_VOTERS=${KAFKA_CONTROLLER_QUORUM_VOTERS:-1000@localhost:9093}
  default_common_envs
}

remove_comments_and_sort() {
  if [ ! -e "$1" ]; then
    return
  fi
  sed -i '/^#/d;/^$/d' "$1"
  sort -o "$1" "$1"
}

convert_envs_to_properties() {
  local -n local_exclude_list="$1"
  dump_file="$2"
  prefix="$3"
  for var in $(env | grep "^$prefix" | cut -d= -f1); do
      # Skip excluded vars
      for exclude in ${local_exclude_list[@]}; do
          if [[ "$var" == "$exclude" ]]; then
              continue 2
          fi
      done

      key=$(from_env_key "$var")
      value="${!var}"
      echo "$key=$value" >> "$dump_file"
  done
  # Sort the properties file and remove comments
  remove_comments_and_sort "$dump_file"
  log "Converted environment variables to properties file: $dump_file"
}

convert_properties_to_envs() {
  local filename="$1"
  local prefix="$2"
  if [[ ! -f "$filename" ]]; then
    warn "File $filename does not exist. continuing without converting properties to environment variables."
    return
  fi
  while IFS='=' read -r key value; do
    # Skip empty lines and comments
    if [[ -z "$key" || "$key" =~ ^# ]]; then
      continue
    fi
    # Convert the key to an environment variable format
    env_key=$(to_env_key "$key")
    # Export the environment variable
    export "$env_key=$value"
  done < "$filename"
}