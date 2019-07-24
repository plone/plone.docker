#!/bin/bash
set -e

COMMANDS="adduser debug fg foreground help kill logreopen logtail reopen_transcript run show status stop wait"
START="console start restart"

su-exec plone python /docker-initialize.py

if [ -e "custom.cfg" ]; then
  if [ ! -e "bin/develop" ]; then
    buildout -c custom.cfg
    chown -R plone:plone /plone
    su-exec plone python /docker-initialize.py
  fi
fi

# ZEO Server
if [[ "$1" == "zeo"* ]]; then
  exec su-exec plone bin/$1 fg
fi

# Plone instance start
if [[ $START == *"$1"* ]]; then
  exec su-exec plone bin/instance console
fi

# Plone instance helpers
if [[ $COMMANDS == *"$1"* ]]; then
  exec su-exec plone bin/instance "$@"
fi

# Custom
exec "$@"
