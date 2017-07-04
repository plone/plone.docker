=====
Swarm
=====

The following configuration creates two ZEO instances which connect to the ZEO server via dedicated network (zeo-net).

Load balancer (`Traefik <https://traefik.io/>`_) and ZEO instances connect via their own network (traefik-net).

Only Traefik exposes its ports (80/TCP and 8080/TCP).

Traefik monitoring interface is at port 8080 and Plone trafik goes through the port 80.

First we need to put Docker in swarm mode:
$ docker swarm init

Create plone-compose.yml with following content:

.. code-block:: yaml

   --
   version: "3"
   services:
     traefik:
       image: library/traefik:latest
       command: --docker --docker.swarmmode --docker.domain=traefik --docker.watch --web
       ports:
         - "80:80"
         - "8080:8080"
       networks:
         - traefik-net
       volumes:
         - /var/run/docker.sock:/var/run/docker.sock
       deploy:
         mode: global
         placement:
           constraints:
             - node.role == manager
     instance:
       image: library/plone:latest
       hostname: plone
       networks:
         - traefik-net
         - zeo-net
       environment:
         - ZEO_ADDRESS=zeo:8100
       deploy:
         replicas: 2
         labels:
           traefik.docker.network: traefik-net
           traefik.port: 8080
           traefik.frontend.rule: Host:plone.traefik
           traefik.backend.loadbalancer.method: drr
     zeo:
       hostname: zeo
       image: library/plone:latest
       command: zeoserver
       volumes:
         - zeo-data:/data
       networks:
         - zeo-net
       deploy:
         mode: global

   volumes:
       zeo-data:

   networks:
       zeo-net:
       traefik-net:

Deploy the stack with following command:

.. code-block:: shell

   docker deploy plone --compose-file plone-compose.yml

Add the following to you /etc/hosts file:

``127.0.0.1	plone.traefik``

Open your browser to http://plone.traefik/ and create a Plone site (use the default values).

After the site is created you can modify the traefik.frontend.rule label so that Traefik loads the site directly from the domain root:

traefik.frontend.rule: *Host:plone.traefik;AddPrefix:/VirtualHostBase/http/plone.traefik:80/Plone/VirtualHostRoot*

Redeploy the configuration with same command as before:

.. code-block:: shell

   docker deploy plone --compose-file plone-compose.yml
