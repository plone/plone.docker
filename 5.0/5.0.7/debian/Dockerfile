FROM python:2.7-slim

RUN useradd --system -m -d /plone -U -u 500 plone \
 && mkdir -p /data/filestorage /data/blobstorage \
 && chown -R plone:plone /data

ENV PLONE_MAJOR=5.0
ENV PLONE_VERSION=5.0.7
ENV PLONE_MD5=347e787d10a6a02d8156ed8c05effcdb

LABEL plone=$PLONE_VERSION \
	  os="debian" \
	  os.version="8" \
	  name="Plone 5" \
	  description="Plone image, based on Unified Installer" \
	  maintainer="Plone Community"

RUN buildDeps="curl sudo python-setuptools python-dev build-essential libssl-dev libxml2-dev libxslt1-dev libbz2-dev libjpeg62-turbo-dev" \
 && runDeps="libxml2 libxslt1.1 libjpeg62 rsync" \
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
 && SUDO_FORCE_REMOVE=yes apt-get remove --purge -y $buildDeps $(apt-mark showauto) \
 && apt-get install -y --no-install-recommends $runDeps \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /plone/buildout-cache/downloads/* \
 && rm -rf /plone/Plone-docs \
 && find /plone \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' +

VOLUME /data

COPY docker-initialize.py docker-entrypoint.sh /

EXPOSE 8080
USER plone
WORKDIR /plone/instance

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
