=======
Add-ons
=======

You can test new or existing Plone add-ons by passing them via the ``PLONE_ADDONS`` environment variable.

The following examples adds `eea.facetednavigation <https://github.com/eea/eea.facetednavigation>`_.

.. code-block:: shell

   docker run -p 8080:8080 -e PLONE_ADDONS="eea.facetednavigation" plone fg

This will start your container in foreground mode and install `eea.facetednavigation <https://github.com/eea/eea.facetednavigation>`_.

After your container started, please follow `the official docs <https://docs.plone.org/adapt-and-extend/config/add-ons.html#add-ons>`_ to enable the add-on in your site.
