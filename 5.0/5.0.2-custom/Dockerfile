FROM python:2.7-slim
MAINTAINER Plone Community

ADD . /plone
WORKDIR /plone
VOLUME /plone/var/blobstorage
VOLUME /plone/var/filestorage

RUN set -x \
   && buildDeps=' \
		curl \
		gcc \
		libbz2-dev \
		libc6-dev \
		libncurses-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
    libxslt-dev \
    libxml2-dev \
    libjpeg-dev \
		make \
		xz-utils \
		zlib1g-dev \
	' \
  && ploneDeps=' \
   libxml2 \
   libxslt1.1 \
   libjpeg62 \
  ' \
	&& apt-get update && apt-get install -y $buildDeps $ploneDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
  && python bootstrap.py && ./bin/buildout -v \
  && find /plone \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
  && apt-get purge -y --auto-remove $buildDeps \
  && chown -R www-data:www-data /plone/*

# Expose
EXPOSE  8080

# Configure and Run
ENTRYPOINT ["/plone/docker-entrypoint.sh"]
CMD ["/plone/bin/instance", "fg"]
