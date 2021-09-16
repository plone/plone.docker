#!/bin/bash
set -e

mkdir -p ${PLONE_BACKEND:-/opt/plone/backend}/var/log
find ${PLONE_BACKEND:-/opt/plone/backend} -not -user ${PLONE_USER:-plone} -exec chown ${PLONE_USER:-plone}:${PLONE_USER:-plone} {} \+

# Plone instance start
if [[ $1 == "start" ]]; then
  exec gosu ${PLONE_USER:-plone} bin/runwsgi -v etc/zope.ini
fi

# Custom
exec "$@"
