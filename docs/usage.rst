Using this image
================
There are two ways to use this image out-of-the-box:

1. Standalone
2. ZEO client

1. Simple usage
---------------
::

  $ docker run -p 8080:8080 plone/plone

Now, ask for http://localhost:8080/ in your workstation web browser,
and add a Plone site.

2. ZEO client
-------------

Considering ZEO server is running at `192.168.1.1` on default port `8100`::

  $ docker run -e ZEO_ADDRESS=192.168.1.1:8100 -p 8080:8080 plone/plone

Now, open http://localhost:8080/ in your workstation web browser. If you
already have a Plone site within ZEO database, click on `View your Plone site`,
otherwise add a new one.

3. Scale
--------
In order to scale up and down the number of ZEO clients you'll need
orchestration tools like `docker-compose <http://docs.docker.com/compose/install/>`_

Bellow is a `docker-compose.yml` example with ZEO server and Plone
instance configured as a ZEO client::

  haproxy:
    image: eeacms/haproxy
    ports:
    - 8080:5000
    - 1936:1936
    links:
    - plone
    environment:
    - BACKENDS_PORT=8080
    - SERVICE_NAMES=plone

  plone:
    image: plone/plone
    links:
    - zeoserver
    environment:
    - ZEO_ADDRESS=zeoserver:8100

  zeoserver:
    image: plone/zeoserver

Start cluster::

  $ docker-compose up -d

Scale the number of ZEO clients::

  $ docker-compose scale plone=4

Now, open http://localhost:8080 in your workstation web browser. To see the
HAProxy backends health, go to http://localhost:1936 Default user: `admin/admin`

4. Debug mode
-------------
You can also start Plone in debug mode (fg) by running::

    $ docker run -p 8080:8080 plone/plone fg

Still, this will not allow you to add `pdb` breakpoints. For this, you'll have
to run Plone inside container like::

    $ docker run -it -p 8080:8080 plone/plone bash
      $ bin/instance fg

5. Extending this image
-----------------------
In order to run Plone with your custom theme or Plone Add-ons, you'll have to
build another image based on this one. For this, you'll need to create two files,
`site.cfg` which is a `zc.buildout <https://pypi.python.org/pypi/zc.buildout/2.5.0>`_
configuration file, and `Dockerfile <https://docs.docker.com/engine/reference/builder/>`
which is the Docker recipe for your image

site.cfg
~~~~~~~~
::

  [buildout]
  extends = buildout.cfg

  [instance]
  eggs += plone.awsome.addon

Dockerfile
~~~~~~~~~~
::

  FROM plone/plone:5

  COPY site.cfg
  RUN bin/buildout -c site.cfg

Build your custom Plone image::

  $ docker build -t plone:custom .

Run it::

  $ docker run -p 8080:8080 plone:custom

Test it at http://localhost:8080
