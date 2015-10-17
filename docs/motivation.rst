Motivation
==========

What is the motivation behind this:

More and more people using virtualization, `Docker <http://docker.com>`_ is getting more and more famous under sysadmins and devops.

For more information about Docker please visit http://docker.com.

These docker images are **really meant as example**, maybe as possible starting point for your own ones.

Please **do not** use them in production environments out of the box. Add some point you want to add a product or change something else, this means you will have to build the image again.

Images and Setup
----------------

The idea here is to start really simple, one image [container] with one instance, based on this we will get to examples with persistent data storage on the host.

Explain how to expose the container to nginx on the host server. 

So for now we will go with:

- instance image
- zeo image

Based on that we will dive even further into it and show/write examples how you can build a setup where you link a zeoserver image together with a couple instances.


Possible scenarios 
------------------

- Show example with `docker-compose <http://docs.docker.com/compose/install/>`_ for easy development on your local machine

- Show example with `systemd <https://en.wikipedia.org/wiki/Systemd/>`_  for production 

- Include nginx container ?

- Include varnish container ?

- Include HA-proxy container ?

Image
-----

- Operating system ?
- squash image
- image cleaning
- build tools in image or usage of a 'build' image and just include build with runtime dependencies ? less is more here
- reduce image layer




