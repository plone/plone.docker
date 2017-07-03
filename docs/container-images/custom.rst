=============
Custom Images
=============

Extending A Base Image
======================

To run Plone with your custom theme or Plone add-ons, you'll have to build another image based on this one.

For this, you'll need to create two files:

- `site.cfg` which is a `zc.buildout <https://pypi.python.org/pypi/zc.buildout/2.5.0>` configuration file
- `Dockerfile <https://docs.docker.com/engine/reference/builder/>`_ which is the Docker recipe for your image


Configuration File
------------------

``site.cfg``

.. code-block:: shell

   [buildout]
   extends = buildout.cfg
   eggs +=
     plone.awsome.addon
     plone.other.addon

   [versions]
   plone.awsome.addon = 1.0
   plone.other.addon = 24.13

   # Required by:
   # plone.other.addon = 24.13
   plone.api = 1.5.1


Dockerfile
----------

.. code-block:: shell

   FROM plone:5

   COPY site.cfg /plone/instance/
   RUN bin/buildout -c site.cfg

Build your custom Plone image

.. code-block:: shell

   docker build -t custom-plone-image .

Run it

.. code-block:: shell

   docker run -p 8080:8080 custom-plone-image
