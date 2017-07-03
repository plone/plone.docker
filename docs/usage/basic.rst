===========
Basic Usage
===========

There are two ways to use this image out-of-the-box, meaning without any additionally configuration.

.. warning::

   This is fine for testing but **not for production**

   Out-of-the-box, this setup has **no data presidency** which means
   by stopping the container you will loose all you data !

Standalone
==========

.. todo::

   Explain: Standalone

.. code-block:: shell

   docker run -p 8080:8080 plone

Open your browser and go to http://localhost:8080/ and add a Plone site.

ZEO Cluster
===========

.. todo::

   Explain ZEO Cluster

Start ZEO server

.. code-block:: shell

   docker run --name=zeo plone zeoserver

Start 2 Plone clients

.. code-block:: shell

   docker run --link=zeo -e ZEO_ADDRESS=zeo:8100 -p 8081:8080 plone
   docker run --link=zeo -e ZEO_ADDRESS=zeo:8100 -p 8082:8080 plone

 Open http://localhost:8080/ in your browser.

If you already have a Plone site, click on ``View your Plone site``, otherwise add a new one.
