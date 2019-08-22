#!/bin/sh
# Container entrypoint ~TBD~
set -euo pipefail

## main #########################################

# ensure requirements are satisfied
pip install -r requirements.txt

# add system packages
apk add jq

# execute argument
eval "$@"
