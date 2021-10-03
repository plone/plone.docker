FROM python:3.8-alpine

ENV PIP=21.0.1 \
    ZC_BUILDOUT=2.13.4 \
    SETUPTOOLS=51.3.3 \
    WHEEL=0.36.2 \
    PLONE_MAJOR=5.2 \
    PLONE_VERSION=5.2.4 \
    PLONE_VERSION_RELEASE=Plone-5.2.4-UnifiedInstaller-1.0 \
    PLONE_MD5=b682cdf2384e692c033077f448b68afd

RUN addgroup -g 500 plone \
 && adduser -S -D -G plone -u 500 plone \
 && mkdir -p /plone/instance /data/filestorage /data/blobstorage

COPY buildout.cfg /plone/instance/

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    libc-dev \
    zlib-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libxml2-dev \
    libxslt-dev \
    mariadb-dev \
    openldap-dev \
    pcre-dev \
    postgresql-dev \
    libffi-dev \
&& wget -O Plone.tgz https://launchpad.net/plone/$PLONE_MAJOR/$PLONE_VERSION/+download/$PLONE_VERSION_RELEASE.tgz \
&& echo "$PLONE_MD5  Plone.tgz" | md5sum -c - \
&& tar -zxvf Plone.tgz \
&& cp -rv ./$PLONE_VERSION_RELEASE/base_skeleton/* /plone/instance/ \
&& cp -v ./$PLONE_VERSION_RELEASE/buildout_templates/buildout.cfg /plone/instance/buildout-base.cfg \
&& pip install pip==$PIP setuptools==$SETUPTOOLS zc.buildout==$ZC_BUILDOUT wheel==$WHEEL \
&& cd /plone/instance \
&& buildout \
&& ln -s /data/filestorage/ /plone/instance/var/filestorage \
&& ln -s /data/blobstorage /plone/instance//var/blobstorage \
&& find /data  -not -user plone -exec chown plone:plone {} \+ \
&& find /plone -not -user plone -exec chown plone:plone {} \+ \
&& rm -rf /Plone* \
&& apk del .build-deps \
&& apk add --no-cache --virtual .run-deps \
    su-exec \
    bash \
    git \
    rsync \
    libxml2 \
    libxslt \
    libjpeg-turbo \
    mariadb-connector-c \
    postgresql-client \
&& rm -rf /plone/buildout-cache/downloads/*

VOLUME /data

COPY docker-initialize.py docker-entrypoint.sh /

EXPOSE 8080
WORKDIR /plone/instance

HEALTHCHECK --interval=1m --timeout=5s --start-period=1m \
  CMD nc -z -w5 127.0.0.1 8080 || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
