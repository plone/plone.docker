==============
Docker Compose
==============

To scale up and down the number of ZEO clients you'll need
orchestration tools like `docker-compose <http://docs.docker.com/compose/install/>`_.

Bellow is a `docker-compose.yml` example with ZEO server and Plone
instance configured as a ZEO client::

  version: "2"
  services:
    haproxy:
      image: eeacms/haproxy
      ports:
      - 8080:5000
      - 1936:1936
      depends_on:
      - plone
      environment:
        BACKENDS: "plone"
        BACKENDS_PORT: "8080"
        DNS_ENABLED: "True"

    plone:
      image: plone
      depends_on:
      - zeoserver
      environment:
      - ZEO_ADDRESS=zeoserver:8100

    zeoserver:
      image: plone
      command: zeoserver
      volumes:
      - data:/data

  volumes:
    data:

Start cluster

.. code-block:: shell

   docker-compose up -d

Scale the number of ZEO clients

.. code-block:: shell

   docker-compose scale plone=4

Now, open http://localhost:8080 in your workstation web browser.

To see the HAProxy backends health, go to http://localhost:1936 and login with: `admin/admin`
