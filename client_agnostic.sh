#!/bin/sh
# Wraps a shell statement and attaches pipe
# to a python event loop, which is used to perform
# operations against the prometheus python client sdk
# https://github.com/prometheus/client_python
set -euo pipefail

## arguments ####################################

export WORKDIR=${WORKDIR:-/opt/bin}
export FD=${FD:-6}

arguments=${@:-"sh -l"}

## properties ###################################

ch=`mktemp -u`

## main #########################################

logger -pdebug -s "Enter"

trap "kill -- -$$" EXIT

# create ipc channel and attach file descriptor
rm -rf $ch
mkfifo $ch
eval "exec ${FD}<>${ch}"


# start metrics interpreter - reap parent on exit
(
  trap "kill -- -$$" EXIT
  $WORKDIR/client_agnostic.py

) <&${FD} &

eval "$@"

# close fd
eval "exec ${FD}&-"

logger -pdebug -s "Exit"
