Motivation
==========

What is the motivation behind this:

More and more people using visualization, `Docker <http://docker.com>`_ is getting more and more famous under sysadmins and devops.

For more information about Docker please visit http://docker.com.

These docker images are really meant as example, starting points or as base for your own ones.

Please **do not** use them in production environments out of the box. Add some point you want to add a product or change something else, this means you will have to build the image again.

Images and Setup
----------------

The idea here is to start really simple, one image with one instance, based on this we will get to examples with persistent data storage on the host and in a data-container.

So for now we will go with:

- instance image
- zeo image

Based on that we will dive even further into it and show/write examples how you can build a setup where you link a zeoserver images together with a couple instances.

One more thing
--------------

Take it even to the next step and also link images with varnish and ha-proxy into this setup.


Cluster
-------

Show an example with `Fig <http://www.fig.sh/>`_ for easy cluster deployments.

Maybe later on even give examples with more advanced management tools.






