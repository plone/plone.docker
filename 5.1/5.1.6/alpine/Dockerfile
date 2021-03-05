FROM python:2.7-alpine

ENV PIP=19.3 \
    ZC_BUILDOUT=2.13.2 \
    SETUPTOOLS=41.4.0 \
    WHEEL=0.33.6 \
    PLONE_MAJOR=5.1 \
    PLONE_VERSION=5.1.6 \
    PLONE_MD5=ff161c4a9b484a43f74b54bd0ff0ec06

LABEL plone=$PLONE_VERSION \
    os="alpine" \
    os.version="3.10" \
    name="Plone 5.1" \
    description="Plone image, based on Unified Installer" \
    maintainer="Plone Community"

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
    openldap-dev \
    pcre-dev \
    libffi-dev \
&& wget -O Plone.tgz https://launchpad.net/plone/$PLONE_MAJOR/$PLONE_VERSION/+download/Plone-$PLONE_VERSION-UnifiedInstaller.tgz \
&& echo "$PLONE_MD5  Plone.tgz" | md5sum -c - \
&& tar -zxvf Plone.tgz \
&& cp -rv ./Plone-$PLONE_VERSION-UnifiedInstaller/base_skeleton/* /plone/instance/ \
&& cp -v ./Plone-$PLONE_VERSION-UnifiedInstaller/buildout_templates/buildout.cfg /plone/instance/buildout-base.cfg \
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
&& rm -rf /plone/buildout-cache/downloads/*

VOLUME /data

COPY docker-initialize.py docker-entrypoint.sh /

EXPOSE 8080
WORKDIR /plone/instance

HEALTHCHECK --interval=1m --timeout=5s --start-period=1m \
  CMD nc -z -w5 127.0.0.1 8080 || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
