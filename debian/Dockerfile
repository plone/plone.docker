# Dockerfile for Debian
FROM python:2.7-slim
MAINTAINER "Plone Community" http://community.plone.org

RUN useradd --system -U -u 500 plone \
 && mkdir -p /plone /data \
 && chown -R plone:plone /plone /data \
 && buildDeps='\
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
 && runDeps='\
    libxml2 \
    libxslt1.1 \
    libjpeg62 \
    ' \
 && apt-get update \
 && apt-get install -y --no-install-recommends $buildDeps $runDeps \
 && curl -k -o Plone-5.0-UnifiedInstaller-r1.tgz https://launchpad.net/plone/5.0/5.0/+download/Plone-5.0-UnifiedInstaller-r1.tgz \
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
 && apt-get purge -y --auto-remove $buildDeps \
 && rm -rf /var/lib/apt/lists/*

USER plone
WORKDIR /plone/instance

ENTRYPOINT ["/plone/instance/bin/instance"]
CMD ["fg"]
