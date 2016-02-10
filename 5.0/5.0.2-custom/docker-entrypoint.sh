#!/bin/bash

echo "START ZOPE"
chown -R www-data:www-data /plone/var

exec "$@"
