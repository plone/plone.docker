#!/bin/bash
set -e

COMMANDS="adduser debug fg foreground help kill logreopen logtail reopen_transcript run show status stop wait"
START="console start restart"

gosu plone python /docker-initialize.py

if [ -e "custom.cfg" ]; then
  if [ ! -e "bin/develop" ]; then
    buildout -c custom.cfg
    find /data  -not -user plone -exec chown plone:plone {} \+
    find /plone -not -user plone -exec chown plone:plone {} \+
    gosu plone python /docker-initialize.py
  fi
fi

# ZEO Server
if [[ "$1" == "zeo"* ]]; then
  exec gosu plone bin/$1 fg
fi

# Plone instance start
if [[ $START == *"$1"* ]]; then
  exec gosu plone bin/instance console
fi

# Plone instance helpers
if [[ $COMMANDS == *"$1"* ]]; then
  exec gosu plone bin/instance "$@"
fi

# Custom
exec "$@"
