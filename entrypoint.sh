#!/bin/sh
# Container entrypoint ~TBD~
set -euo pipefail


## sources ######################################

source "`dirname ${0}`/lib.sh"

## arguments ####################################

export WBDR=${WBDR:-/opt/www}

## main #########################################

# reap every on exit
trap "kill -- -$$" EXIT

# ensure requirements are satisfied
pip install -r requirements.txt

# add system packages
apk add jq curl busybox-extras

# setup http directory
mkdir -p ${WBDR}/cgi-bin
realpath *.sh | xargs -I{} ln -sf {} ${WBDR}/cgi-bin

# start http server
(
  httpd \
    -f \
    -v \
    -p 8080 \
    -h $WBDR
) >/tmp/http.log &

# execute argument
eval "$@"
