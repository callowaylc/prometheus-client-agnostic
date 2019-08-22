#!/usr/bin/env python
import os
import re
import sys
import json
import stat
import socket
import logging
import inspect
import traceback
from uuid import uuid1
from time import time
from logging import StreamHandler
from logging.handlers import SysLogHandler

## constants ####################################

JOURNALD_SOCK = "/run/systemd/journal/socket"
LOG_FILEDESCRIPTOR = 3

## properties ###################################

codex = {
  "debug": 7,
  "info": 6,
  "notice": 5,
  "warning": 4,
  "err": 3,
  "crit": 2,
  "alert": 1,
  "emerg": 0
}

## functions ####################################

def __priority__(level):
  """Convert string level to syslog priority integer
  """
  retval = next(
    ( v for k, v in codex.items() if re.match(k, level, re.IGNORECASE) ), None
  )
  if not retval:
    raise Exception(
      "Failed to determine priority for the given level", level,
    )

  return retval


def logger():
  """ Provides singleton access to logger instance
  """
  l = logging.getLogger(__file__)
  if not len(l.handlers):
    mask = os.getenv("PRIORITY", "INFO").upper()

    if mask == "ERR":
      mask = "ERROR"
    elif mask == "WARN":
      make = "WARNING"
    l.setLevel(mask)

    # add file descriptor handler; all log messages are written to fd 3
    # which is by default written to devnull device
    try:
      # determine if log fd is available; if it is not, an
      # exception will be thrown and we will create an fd and
      # point it to /dev/null
      os.fstat(LOG_FILEDESCRIPTOR)
    except:
      os.dup2(
        os.open(os.devnull, os.O_WRONLY), LOG_FILEDESCRIPTOR
      )

    handler = StreamHandler(os.fdopen(LOG_FILEDESCRIPTOR, "w"))
    l.addHandler(handler)

    # add syslog handler if passed
    # TODO: add a journald handler
    if os.getenv("SYSLOG", None):
      if  os.path.exists(JOURNALD_SOCK) and \
          stat.S_ISSOCK(os.stat(JOURNALD_SOCK).st_mode):
            l.addHandler(JournaldHandler())
      else:
        l.addHandler(SysLogHandlerDelimited())

  return l

def debug(message, attributes={ }):
  log("debug", message, attributes)
def info(message, attributes={ }):
  log("info", message, attributes)
def warn(message, attributes={ }):
  log("warning", message, attributes)
def warning(message, attributes={ }):
  log("warning", message, attributes)
def error(message, attributes={ }):
  log("error", message, attributes)
def err(message, attributes={ }):
  log("error", message, attributes)

def log(level, message, attributes = { }):
  """ Generates a structured message as json payload
  """
  entry = inspect.stack()[2]
  trace = "%s#%s" % (entry[1], str(entry[3]))
  priority = __priority__(level)
  attributes.update({
    "message": message,
    "message_id": str(uuid1()),
    "level": level,
    "priority": priority,
    "trace": trace,
    "timestamp": int(time()),
  })

  # uppercase keys
  attributes = { k.upper():v for k, v in attributes.items() }
  priorityFunction = getattr(logger(), level)
  priorityFunction(json.dumps(attributes))

## classes ######################################

class JournaldHandler(StreamHandler):
  """ A python logging facility to wire-up journald
  """
  def __init__(self):
    StreamHandler.__init__(self, os.devnull)
    self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    self.sock.connect(JOURNALD_SOCK)

  def emit(self, record):
    payload = "\n".join([ "%s=%s" % (k.upper(), v)
      for k, v in json.loads(record.getMessage()).items()
    ])
    self.sock.sendall(payload)

class SysLogHandlerDelimited(SysLogHandler):
  """ Extends the STDLIB SysLogHandler to format message for syslog consumption
  """
  def __init__(self):
    socket = "/dev/log"
    if os.path.exists("/var/run/syslog"):
      # syslog socket path on mac osx
      socket = "/var/run/syslog"

    SysLogHandler.__init__(self, address=socket)

  def emit(self, record):
    payload = json.loads(record.getMessage())
    message = "%s : " % payload["message"]

    for k, v in payload.items():
      message += "%s=%s; " % (k.upper(), v)

    self.socket.send(message)
