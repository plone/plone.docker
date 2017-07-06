==========
Debug Mode
==========

You can start Plone in debug mode (fg) by running

.. code-block:: shell

   docker run -p 8080:8080 plone fg

Debugging With Pdp
==================

You can use the the python debugger [Pdp] inside the container.

For this, you'll have to run Plone inside container like

.. code-block:: shell

   docker run -it -p 8080:8080 plone bash
   bin/instance fg
