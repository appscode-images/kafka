#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

. /opt/kafka/scripts/lib.sh

info "** Starting setup **"

config_dir="/opt/kafka/config"
final_config_path="${config_dir}/kafka.properties"

debug "Updating envs with default values if not set"
## Default environment variables
default_combined_envs

exclude_envs=(
  "KAFKA_CLUSTER_ID"
  "KAFKA_USER"
  "KAFKA_PASSWORD"
  "KAFKA_SCRAM_256_USERS"
  "KAFKA_SCRAM_512_USERS"
  "KAFKA_SCRAM_256_KAFKA_PASSWORDS"
  "KAFKA_SCRAM_512_KAFKA_PASSWORDS"
  "KAFKA_JVM_PERFORMANCE_OPTS"
  "KAFKA_JMX_OPTS"
)

debug "Converting environment variables to properties file format exept excluded envs"
# Convert environment variables to properties file format
convert_envs_to_properties exclude_envs $final_config_path "KAFKA_"

info "** Kafka setup completed **"

exec /opt/kafka/scripts/start.sh "$final_config_path"