=======
Add-ons
=======

You can test new or existing Plone add-ons by passing them via the ``PLONE_ADDONS`` environment variable.

The following examples adds the `eea.facetednavigation <https://github.com/eea/eea.facetednavigation>`_.

.. code-block:: shell

   docker run -p 8080:8080 -e PLONE_ADDONS="Products.PloneFormGen eea.facetednavigation" plone fg
