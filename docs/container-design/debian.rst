======
Debian
======

.. admonition:: This files explains the structure of the `Debian <https://debian.org>`_ based Dockerfile.

.. code-block:: docker

   FROM python:2.7-slim

The FROM instruction sets the Base Image (here the official python.2.7-slim image) for subsequent instructions.

.. code-block:: docker

   LABEL plone=$PLONE_VERSION \
      os="debian" \
      os.version="8" \
      name="Plone 4" \
      description="Plone image, based on Unified Installer" \
      maintainer="Plone Community"

The *LABEL* instruction adds metadata to an image. A *LABEL* is a key-value pair.

.. code-block:: docker

   RUN useradd --system -m -d /plone -U -u 500 plone \
   && mkdir -p /data/filestorage /data/blobstorage \
   && chown -R plone:plone /data \

- Creates the user plone
- Creates needed directories and sets permissions

.. code-block:: docker

   && buildDeps="wget sudo python-setuptools python-dev build-essential libssl-dev libxml2-dev libxslt1-dev libbz2-dev libjpeg62-turbo-dev libtiff5-dev libopenjp2-7-dev" \

Dependencies (packages) which are needed for building Plone

.. code-block:: docker

   && runDeps="libxml2 libxslt1.1 libjpeg62 rsync lynx wv libtiff5 libopenjp2-7 poppler-utils" \

Dependencies (packages) which are needed for running Plone

.. note::

    We split packages into *build* and *run* dependencies, the reason for that is to make it easier to keep the image small.

.. code-block:: docker

  && apt-get update \
  && apt-get install -y --no-install-recommends $buildDeps \

Run update and install all packages we need for building Plone.

.. code-block:: docker

   && wget -O Plone.tgz https://launchpad.net/plone/$PLONE_MAJOR/$PLONE_VERSION/+download/Plone-$PLONE_VERSION-UnifiedInstaller.tgz \
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

Download Plone and build it, using the Unified Installer with certain options.

.. code-block:: docker

   && cd /plone/instance \

Change into the directory of Plone.

.. code-block:: docker

   && sed -i 's/parts =/parts =\n    zeoserver/g' buildout.cfg \
   && echo '\n[zeoserver]\n<= zeoserver_base\nrecipe = plone.recipe.zeoserver' >> buildout.cfg \

t.b.c

.. code-block:: docker

   && sudo -u plone bin/buildout \
   && chown -R plone:plone /plone /data \

Set permissions

.. code-block:: docker

   && rm -rf /Plone* \

Remove not needed files.

.. code-block:: docker

   && SUDO_FORCE_REMOVE=yes apt-get remove --purge -y $buildDeps \

Remove all package which were needed for building.

.. code-block:: docker

   && apt-get install -y --no-install-recommends $runDeps \

Install all packages which are needed for running Plone

.. code-block:: docker

   && rm -rf /var/lib/apt/lists/* \
   && rm -rf /plone/buildout-cache/downloads/* \
   && rm -rf /plone/Plone-docs \
   && find /plone \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' +

Cleanup, remove files which are not needed.
