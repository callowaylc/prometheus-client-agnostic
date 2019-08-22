#!/bin/sh
# Write nil string to stdout N number of times
# and check
set -euo pipefail

## arguments ####################################

FD=${FD}

metricname=${2:-example}
metrichost=${3:-localhost}

## main #########################################

# write headers to stdout
echo "Status: 200 OK"
echo
echo

# increment the counter by writing to $FD
echo >&${FD}
sleep .1

# get counter value and write to stdout/http response body
curl -s $metrichost/metrics \
  | grep -Ei "${metricname}_total" \
  | awk '{ print $2 }'
