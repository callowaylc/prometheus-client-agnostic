#!/bin/sh
set -euo pipefail
! set -o errtrace 2>/dev/null

[[ "${LIB_SOURCED:-}" = "true" ]] && return 0

{ >&3 ;} 2>/dev/null || exec 3>/dev/null
{ >&4 ;} 2>/dev/null || exec 4>/dev/null

## constants ####################################

LIB_SOURCED=true
EXT_ARGUMENT=3

PRI_DEBUG=7
PRI_INFO=6
PRI_WARN=4
PRI_ERR=3
PRI_ERROR=3

## functions ####################################

function ref {
  # posix-compliant method to determine indirect reference
  # or target; the second argument acts as a setter, if present
  local target=${1}
  local value=${2:-}
  local target

  ( eval ': ${'$target'?}' ) || {
    ilogs error "Reference does not exist" \
      "trace=@ref#$LINENO" \
      "target=$target"
    exit 3
  }

  if [[ -n "$value" ]]; then
    eval $target'="'"$value"'"'

  else
    eval 'echo "$'$target'"' | sed -E 's/^\$//'
  fi
}

function slice {
  # determine given argument at index to account
  # for alpine not supporting positional splitting.
  # Indicies start at 1 to accomadate shell expectation
  # that positional parameter $@ starts at 1
  local index=${1}
  local length=${2}
  local counter

  shift 2
  if [[ "$length" = "-" ]]; then
    length=$(( $# - 1 ))
  fi

  if [[ "$length" -gt "$#" ]]; then
    ilogs error "Slice length is out of bounds" \
      "trace=@slice#$LINENO" \
      "length=$length" \
      "size=$#"
    exit 3
  fi

  counter=0
  shift $(( index-1 ))
  for value in "$@"; do
    if let "counter++ < $length"; then
      echo "$value"

    else break
    fi
  done
}

function severity {
  local name=${1}
  local reference

  reference="PRI_`echo $name | tr a-z A-Z`"

  ( ref $reference ) || {
    ilogs error "Unknown priority name" \
      "trace=@severity#$LINENO" \
      "name=$name"
    exit 3
  }
}

function ilogs {
  # uses built-in logger to perform "internal" logging, or logging
  # within lib code
  local level=${1}
  local message=${2}

  shift 2
  logger \
    -p $level \
    -t "`date --rfc-3339=ns`$0[$$]" \
    -s "$message" -- \
      "--" \
      "$@"
} 2>&3

function logs {
  local level=${1}
  local message=${2}
  local dump=${3:-}
  local sevnum

  if [[ "$dump" = "-" ]]; then
    # cat stdin if message passed as -; if stdin
    # is open, and empty, this will block

    set -- "stdin=`cat -`"
  fi

  shift 2
  printf '%s\n' \
    "timestamp=`date +%s%N | cut -b1-13`" \
    "level=$level" \
    "priority=`severity $level`" \
    "message=$message" \
    "message_id=`uuidgen`" \
    "_pid=$$" \
    "$@" \
  | jq -crs --raw-input '
      split("\n")[:-1] | map(
        split("=")
          | {(.[0]): .[1]}
          | with_entries( .key |= ascii_upcase )
      )
      | add
    '
} >&3

function encode {
  # base64 and strip newline
  value=${1}

  echo "$value" \
    | base64 \
    | tr -d \\n
}

function uuidgen {
  # cross platform uuid generator
  command uuidgen \
  || cat /proc/sys/kernel/random/uuid 2>/dev/null \
  || echo -

} 2>/dev/null

function respond {
  # creates well-formed http response, writes
  # to, and then closes, stdout
  local code=${1}
  local message=${2}
  local body=${3}
  local ctx
  local headers
  local status

  # any remaining arguments are considered to be
  # key:value pairs, which represent the response
  # headers
  shift 3
  set -- "$@" "Request: ${REQUEST_ID:--}"

  headers="${@}"
  ctx="trace=lib.sh#respond"
  status="pass"

  ilogs DEBUG "Enter" $ctx \
    "code=$code" \
    "msg=$message" \
    "headers=`encode "$headers"`"

  if [[ "$code" -ge 400 ]]; then
    status="fail"

  elif [[ "$code" -ge 299 ]]; then
    status="warn"
  fi
  ilogs DEBUG "Determined status" $ctx \
    "status=$status" \
    "code=$code"

  printf "HTTP/1.0 %s %s\n" $code "$message"
  printf "%s\n" "$@"
  printf "\n"
  printf "%s\n" "`jq \
    -c \
    -n \
    --arg status $status \
      '{ status: $status }'
  `"

  # close stdout to prevent any further writes
  # to stdout
  exec 1>&-
  ilogs DEBUG "Exit" $ctx
}
