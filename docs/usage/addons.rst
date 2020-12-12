=======
Add-ons
=======

You can test new or existing Plone add-ons by passing them via the ``PLONE_ADDONS`` environment variable.

The following examples adds `eea.facetednavigation <https://github.com/eea/eea.facetednavigation>`_.

.. code-block:: shell

   docker run -p 8080:8080 -e PLONE_ADDONS="eea.facetednavigation" plone fg

This will start your container in foreground mode and install `eea.facetednavigation <https://github.com/eea/eea.facetednavigation>`_.

After your container started, please follow `the official docs <https://docs.plone.org/adapt-and-extend/config/add-ons.html#add-ons>`_ to enable the add-on in your site.

The same way as above you can pass `PLONE_ZCML` environment variable to include
custom ZCML files or `PLONE_DEVELOP` environment variable to develop new or
existing Plone add-ons:

.. code-block:: shell

   docker run -p 8080:8080 \
   	-e PLONE_ADDONS="plone.theme.winter" \
   	-e PLONE_DEVELOP="src/plone.theme.winter" \
   	-v $(pwd)/src:/plone/instance/src \
   plone fg

Make sure that you have your Plone add-on code at `src/plone.theme.winter` and
that Plone user inside Docker container (`uid: 500`) has the rights to read/write there:

.. code-block:: shell

   setfacl  -R -m u:500:rwX src/
   setfacl -dR -m u:500:rwX src/
   getfacl src/

Running unit tests:

.. code-block:: shell

   docker run --rm -e PLONE_ADDONS="eea.facetednavigation" \
             plone \
             bin/test -v -vv -s eea.facetednavigation

.. note::

  Please note that passing `PLONE_` environment variables will slow down
  container creation as a buildout re-run inside container is triggered.

  It is **strongly** recommend to use this only for testing or development purpose.

  For production use, create a new image as described.

Theme development
=================
You can mount a local `resources` folder to serve diazo theme resources `from resources/theme/mycustom.theme`.
Please refer to `plone.resource <https://pypi.org/project/plone.resource>`_ for more details and setup instructions.

.. code-block:: shell

   docker run --rm -v $(pwd)/resources:/plone/instance/resources -p 8080:8080 plone

Make sure that you have your Plone diazo theme code at `resources/theme/mycustom.theme` and
that Plone user inside Docker container (`uid: 500`) has the rights to read/write there:

.. code-block:: shell

   setfacl  -R -m u:500:rwX resources/
   setfacl -dR -m u:500:rwX resources/
   getfacl resources/
