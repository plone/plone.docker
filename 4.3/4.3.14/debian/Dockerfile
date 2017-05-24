FROM python:2.7-slim
MAINTAINER "Plone Community" http://community.plone.org

RUN useradd --system -m -d /plone -U -u 500 plone \
 && mkdir -p /data/filestorage /data/blobstorage \
 && chown -R plone:plone /data

ENV PLONE_MAJOR=4.3
ENV PLONE_VERSION=4.3.12
ENV PLONE_MD5=62291e00e1b86b8794772e6841a29570

LABEL plone.version=$PLONE_VERSION
LABEL os="debian" os.version="8"

RUN buildDeps="curl sudo python-setuptools python-dev build-essential libssl-dev libxml2-dev libxslt1-dev libbz2-dev libjpeg62-turbo-dev libtiff5-dev libopenjp2-7-dev" \
 && runDeps="libxml2 libxslt1.1 libjpeg62 rsync lynx wv libtiff5 libopenjp2-7 poppler-utils" \
 && apt-get update \
 && apt-get install -y --no-install-recommends $buildDeps \
 && curl -o Plone.tgz -SL https://launchpad.net/plone/$PLONE_MAJOR/$PLONE_VERSION/+download/Plone-$PLONE_VERSION-UnifiedInstaller.tgz \
 && echo "$PLONE_MD5 Plone.tgz" | md5sum -c - \
 && tar -xzf Plone.tgz \
 && ./Plone-$PLONE_VERSION-UnifiedInstaller/install.sh \
      --password=admin \
      --daemon-user=plone \
      --owner=plone \
      --group=plone \
      --target=/plone \
      --instance=instance \
      --var=/data \
      none \
 && cd /plone/instance \
 && sed -i 's/parts =/parts =\n    zeoserver/g' buildout.cfg \
 && echo '\n[zeoserver]\n<= zeoserver_base\nrecipe = plone.recipe.zeoserver' >> buildout.cfg \
 && sudo -u plone bin/buildout \
 && chown -R plone:plone /plone /data \
 && rm -rf /Plone* \
 && SUDO_FORCE_REMOVE=yes apt-get purge -y --auto-remove $buildDeps \
 && apt-get install -y --no-install-recommends $runDeps \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /plone/buildout-cache/downloads/* \
 && find /plone \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' +

VOLUME /data

COPY docker-initialize.py docker-entrypoint.sh /

EXPOSE 8080
USER plone
WORKDIR /plone/instance

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
