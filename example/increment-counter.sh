#!/bin/sh
# Write nil string to stdout N number of times
# and check
set -euo pipefail

## arguments ####################################

iterations=${1:-10}
metricname=${2:-example}
metrichost=${3:-localhost}

## main #########################################

for i in `seq 0 $(( iterations - 1 ))`; do
  echo "operation: $i" >&6

  curl -s $metrichost/metrics \
    | grep -Ei "${metricname}_total" \
    | awk '{ print $2 }'
done
