FROM python:2.7-alpine
MAINTAINER "Plone Community" http://community.plone.org

RUN addgroup -g 500 plone \
 && adduser -S -D -G plone -u 500 plone \
 && mkdir -p /plone /data \
 && chown -R plone:plone /plone /data \
 && apk add --no-cache --virtual .build-deps  \
    bzip2-dev \
    gcc \
    libc-dev \
    ncurses-dev \
    openssl-dev \
    readline-dev \
    zlib-dev \
    sudo \
    make \
    libxml2-dev \
    libxslt-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    openssl \
 && wget http://launchpad.net/plone/5.0/5.0/+download/Plone-5.0-UnifiedInstaller-r1.tgz \
 && tar -zxvf Plone-5.0-UnifiedInstaller-r1.tgz \
 && ./Plone-5.0-UnifiedInstaller-r1/install.sh \
      --password=admin \
      --daemon-user=plone \
      --owner=plone \
      --group=plone \
      --target=/plone \
      --instance=instance \
      --var=/data \
      standalone \
 && rm -rf Plone-5.0-UnifiedInstaller-r1.tgz /Plone-5.0-UnifiedInstaller-r1 \
 && apk del .build-deps \
 && apk add --no-cache --virtual .run-deps \
    libxml2 \
    libxslt \
    libjpeg-turbo

USER plone
WORKDIR /plone/instance

ENTRYPOINT ["/plone/instance/bin/instance"]
CMD ["fg"]
