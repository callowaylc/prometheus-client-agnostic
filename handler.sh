#!/bin/sh
# Receives alertmanager payload from STDIN, determines recevier,
# and executes the receivers handler with given arguments
# ./route $argsbase64
set -euo pipefail

## constants ####################################

RESPONSE_OK=200
RESPONSE_WARN=300
RESPONSE_FAIL=400
RESPONSE_FAIL_SERVER=500

## imports ######################################

source "`dirname ${0}`/lib.sh"

## arguments ####################################

export REQUEST_ID=${REQUEST_ID:-`uuidgen`}
export HANDLERARGS=${HANDLERARGS:-}

if [[ -z "$HANDLERARGS" ]]; then
  logs ERROR "Missing required ENV" "name=HANDLERARGS"
  respond 500 "Missing ENV"
  exit 3
fi

## properties ###################################

payload="`cat -`"
ctx="
  trace=${0}#main
  requestid=${REQUEST_ID}
"
count=0
receiver=""
args=""

## main #########################################

logs DEBUG "Enter" $ctx \
  "payload=`encode "$payload"`" \
  "args=${HANDLERARGS}" \
  "method=${REQUEST_METHOD}" \
  "resource=${REQUEST_URI}"

# validate payload; specifically whether it is
# valid json and contains required fields
[[ -n "$payload" ]] \
  && echo $payload \
    | jq -e . \
    | jq -e 'select(.receiver != null)' \
    | jq -e 'has("alerts")' &>/dev/fd/4 \
  || {
  logs ERROR "Invalid payload" $ctx "payload=$payload"
  respond 400 "Invalid Payload"

  exit 3
}

# determine receiver
receiver=`echo $payload | jq -r .receiver`
ctx="${ctx} receiver=$receiver"
logs INFO "Determined receiver" $ctx

# get arguments for receiver, which are
# part of the passed "args" hash
args=$(
  echo $HANDLERARGS \
    | base64 -d \
    | jq -re '.'$receiver' | join(" ")' \
  ||  {
    logs ERROR "Failed to determine receiver arguments" && \
    respond 400 "Receiver Arguments Missing"
    exit 3
  }
)
logs DEBUG "Determined receiver arguments" $ctx \
  "receiverargs=`encode "$args"`"

# get number of firing alerts
alerts=$(
  echo $payload | jq -re '
    .alerts
      | map(select(.status == "firing" ))
  '
)
count=$( echo $alerts | jq -r 'length' )
if [[ "$count" -gt 0 ]]; then
  # if there are alerts firing, then we can consider this
  # an actionable event, and pass along to receiver to
  # manage domain specific details of routing alert
  logs ERROR "Alerts firing" $ctx \
    "count=$count" \
    "total=`echo $payload | jq -re '.alerts | length'`"

  for i in `seq 0 $(( count - 1 ))`; do
    # iterate through firing alerts and forward them
    # individually to the appropriate receiver
    alert=`echo $alerts | jq ".[$i]"`
    statement="`realpath .`/${receiver}.sh ${args}"
    logs INFO "Forwarding alert" $ctx \
      "alert=`encode "$alert"`" \
      "statement=$statement" \
      "index=$i"

    echo "$alert" | $statement || {
      logs "Failed to forward alert"
      repond 500 "Alert Submission Failed"

      exit 5
    }
  done

  respond 299 "Alerts Firing" \
    "Location: `echo $payload | jq '.externalURL'`"
fi

logs DEBUG "Exit" $ctx \
  "status=$?"
