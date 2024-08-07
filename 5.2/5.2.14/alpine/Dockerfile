FROM python:3.8-alpine

ENV PIP=22.2.2 \
    ZC_BUILDOUT=3.0.1 \
    SETUPTOOLS=65.7.0 \
    WHEEL=0.38.4 \
    PLONE_MAJOR=5.2 \
    PLONE_VERSION=5.2.14 \
    PLONE_VERSION_RELEASE=Plone-5.2.14-UnifiedInstaller-1.0 \
    PLONE_MD5=e8e1f774f069026319be3038631e0734

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
# some package needs PyYAML 5.4.1, and this can only be built with cython<3.0.0
&& pip install "cython<3.0.0" && pip install --no-build-isolation pyyaml==5.4.1 \
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
    libldap \
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
