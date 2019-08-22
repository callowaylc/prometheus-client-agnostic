#!/usr/bin/env python
import os
import sys
import time
import random
import traceback

from prometheus_client import start_http_server, Counter

from logger import debug, info, warn, error

## constants ####################################

PORT = 80
EXIT_STATUS_ERROR = 3

## main #########################################

def main(arguments):
  debug("Enter", { "arguments": arguments, })

  port = os.environ.get("PORT", PORT)
  c    = Counter("example", "description")
  op   = None

  # start metrics server
  debug("Start metrics server", { "port": port })
  start_http_server(port)

  # start blocking read loop against STDIN
  # TBD: replace with event loop
  debug("Start event loop")
  while True:
    op = sys.stdin.readline()
    debug("Recieved metrics operation", { "operation": op })

    # increment the example counter as stand-in for evaluating
    # metrics operation
    c.inc()

  debug("Exit")


if __name__ == "__main__":
    try:
      sys.exit(main(sys.argv[1:]))

    except Exception as e:
        traceback.print_exc()
        sys.exit(EXIT_STATUS_ERROR)

