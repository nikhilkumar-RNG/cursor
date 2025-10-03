#!/usr/bin/env bash
set -euo pipefail

LOKI_ADDR=${LOKI_ADDR:-http://loki.observability.svc.cluster.local:3100}
QUERY=${1:-"{namespace=\"default\"} |= \"error\""}
SINCE=${SINCE:-1h}
LIMIT=${LIMIT:-1000}

if ! command -v logcli >/dev/null 2>&1; then
  echo "logcli not found. Install from https://github.com/grafana/loki/releases" >&2
  exit 1
fi

export LOKI_ADDR
echo "Query: $QUERY"
time logcli --stats query --limit=$LIMIT --since=$SINCE "$QUERY" >/dev/null
