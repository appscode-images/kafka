#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

. /opt/kafka/scripts/lib.sh

export KAFKA_CLUSTER_ID=${KAFKA_CLUSTER_ID:-4L6g3nShT-eMCtK--X86sw}

info "** Starting Kafka **"
exec "$@"