FROM python:3.9-slim-buster

ARG PLONE_DIST_URL=https://dist.plone.org/release/6.0-dev/
ENV PLONE_BACKEND /opt/plone/backend
ENV PLONE_USER plone
ENV PLONE_ADMIN_USER admin
ENV PLONE_ADMIN_PASS admin

RUN groupadd --gid 1000 $PLONE_USER \
 && useradd -m -d /home/$PLONE_USER -u 1000 --gid $PLONE_USER -s /bin/bash $PLONE_USER \
 && mkdir -p $PLONE_BACKEND

RUN buildDeps="default-libmysqlclient-dev dpkg-dev gcc libbz2-dev libc6-dev libffi-dev libjpeg62-turbo-dev libldap2-dev libopenjp2-7-dev libpcre3-dev libpq-dev libsasl2-dev libssl-dev libtiff5-dev libxml2-dev libxslt1-dev wget zlib1g-dev" \
 && runDeps="default-libmysqlclient-dev git gosu libjpeg62 libopenjp2-7 libpq5 libtiff5 libxml2 libxslt1.1 lynx netcat poppler-utils rsync wv" \
 && apt-get update \
 && apt-get install -y --no-install-recommends $buildDeps \
 && mkdir -p $PLONE_BACKEND \
 && python3 -m venv $PLONE_BACKEND \
 && cd $PLONE_BACKEND \
 && bin/pip install --no-cache-dir -r $PLONE_DIST_URL/requirements.txt \
 && bin/pip install --no-cache-dir -c $PLONE_DIST_URL/constraints.txt Plone --use-deprecated legacy-resolver -f $PLONE_DIST_URL \
 && apt-get purge -y --auto-remove $buildDeps \
 && apt-get install -y --no-install-recommends $runDeps \
 && rm -rf /var/lib/apt/lists/* \
 && cd $PLONE_BACKEND \
 && bin/mkwsgiinstance -u $PLONE_ADMIN_USER:$PLONE_ADMIN_PASS -d . \
 && sed -i "s|127.0.0.1|0.0.0.0|g" etc/zope.ini \
 && find $PLONE_BACKEND -not -user $PLONE_USER -exec chown $PLONE_USER:$PLONE_USER {} \+

EXPOSE 8080
WORKDIR $PLONE_BACKEND

HEALTHCHECK --interval=1m --timeout=5s --start-period=1m \
  CMD nc -z -w5 127.0.0.1 8080 || exit 1

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
