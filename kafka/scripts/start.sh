#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

. /opt/kafka/scripts/lib.sh

debug "** Starting Kafka storage formatting and run server **"

final_config="$1"

storage_args=("--cluster-id" "$KAFKA_CLUSTER_ID" "--config" "$final_config" "--ignore-formatted")
add_scram_credentials() {
  for (( i = 0; i < 2; i++ )); do
    algo_type="$((256 + i * 256))"
    users_var="KAFKA_SCRAM_${algo_type}_USERS"
    passwords_var="KAFKA_SCRAM_${algo_type}_PASSWORDS"

    users_value="${!users_var:-}"
    passwords_value="${!passwords_var:-}"

    if [[ -n "$users_value" && -n "$passwords_value" ]]; then
      debug "Adding SCRAM-SHA-${algo_type} credentials"
      IFS=',' read -ra users <<< "$users_value"
      IFS=',' read -ra passwords <<< "$passwords_value"
      for index in "${!users[@]}"; do
        if [[ -n "${users[$index]}" && -n "${passwords[$index]}" ]]; then
          storage_args+=("--add-scram" "SCRAM-SHA-${algo_type}=[name=${users[$index]},password=${passwords[$index]}]")
        fi
      done
    fi
  done
}

# Add SCRAM credentials if provided
add_scram_credentials
# TODO(): Add support for dynamic quorum changes
#  https://cwiki.apache.org/confluence/display/KAFKA/KIP-853%3A+KRaft+Controller+Membership+Changes#:~:text=In%20this%20case%2C%20the%20controller,the%20beginning%20of%20this%20section.

# Make a temp env variable to store user provided performance otps
if [[ -z "${KAFKA_JVM_PERFORMANCE_OPTS-}" ]]; then
    export TEMP_KAFKA_JVM_PERFORMANCE_OPTS=""
else
    export TEMP_KAFKA_JVM_PERFORMANCE_OPTS="$KAFKA_JVM_PERFORMANCE_OPTS"
fi
# We will first use CDS for storage to format storage
export KAFKA_JVM_PERFORMANCE_OPTS="${KAFKA_JVM_PERFORMANCE_OPTS-} -XX:SharedArchiveFile=/opt/kafka/storage.jsa"

info "** Formatting storage **"
kafka-storage.sh format "${storage_args[@]}"

# Using temp env variable to get rid of storage CDS command
export KAFKA_JVM_PERFORMANCE_OPTS="$TEMP_KAFKA_JVM_PERFORMANCE_OPTS"
# Now we will use CDS for kafka to start kafka server
export KAFKA_JVM_PERFORMANCE_OPTS="$KAFKA_JVM_PERFORMANCE_OPTS -XX:SharedArchiveFile=/opt/kafka/kafka.jsa"

info ** "Starting Kafka Server **"
exec kafka-server-start.sh "$final_config"
