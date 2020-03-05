=============
Custom Images
=============

.. topic:: Description

   This document explains how you can extend and build the *plone.docker* base image with your custom theme and Add-ons, using a *site.cfg* configuration file.

To run Plone with your custom theme or Plone Add-ons, you'll have to build another image based on this one.

For this, you'll need to create two files:

- `site.cfg` which is a `zc.buildout <https://pypi.python.org/pypi/zc.buildout/2.5.0>` configuration file
- `Dockerfile <https://docs.docker.com/engine/reference/builder/>`_ which is the Docker recipe for your image


Configuration File
------------------

``site.cfg``

.. code-block:: bash

   [buildout]
   extends = buildout.cfg
   eggs +=
     plone.awesome.addon
     plone.other.addon

   [versions]
   plone.awesome.addon = 1.0
   plone.other.addon = 24.13

   # Required by:
   # plone.other.addon = 24.13
   plone.api = 1.5.1


Dockerfile
----------

.. code-block:: bash

   FROM plone:5

   COPY site.cfg /plone/instance/
   RUN buildout -c site.cfg \
    && find /data  -not -user plone -exec chown plone:plone {} \+ \
    && find /plone -not -user plone -exec chown plone:plone {} \+

Build your custom Plone image

.. code-block:: shell

   docker build -t custom-plone-image .

Run it

.. code-block:: shell

   docker run -p 8080:8080 custom-plone-image
