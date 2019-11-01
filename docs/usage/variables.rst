===============================
Supported Environment Variables
===============================

.. note::

   Using environment variables requires advanced knowledge of Plone.

For Basic Usage
===============

* ``SITE`` - Add Plone with this id to `Data.fs` on first run. If NOT provided, you'll have to manually add a Plone Site via web UI (*v5.2+*)
* ``ADDONS`` - Customize Plone via Plone add-ons using this environment variable
* ``ZEO_ADDRESS`` - This environment variable allows you to run Plone image as a ZEO client.


For Advanced Usage
==================

* ``PLONE_ZCML``, ``ZCML`` - Include custom Plone add-ons ZCML files
* ``PLONE_DEVELOP``, ``DEVELOP`` - Develop new or existing Plone add-ons
* ``ZEO_READ_ONLY`` - Run Plone as a read-only ZEO client. Defaults to `off`.
* ``ZEO_CLIENT_READ_ONLY_FALLBACK`` - A flag indicating whether a read-only remote storage should be acceptable as a fallback when no writable storages are available. Defaults to `false`.
* ``ZEO_SHARED_BLOB_DIR`` - Set this to on if the ZEO server and the instance have access to the same directory. Defaults to `off`.
* ``ZEO_STORAGE`` - Set the storage number of the ZEO storage. Defaults to `1`.
* ``ZEO_CLIENT_CACHE_SIZE`` - Set the size of the ZEO client cache. Defaults to `128MB`.
* ``ZEO_PACK_KEEP_OLD`` - Can be set to false to disable the creation of .fs.old files before the pack is run. `Defaults to true`.
* ``HEALTH_CHECK_TIMEOUT`` - Time in seconds to wait until health check starts. Defaults to `1` second.
* ``HEALTH_CHECK_INTERVAL`` - Interval in seconds to check that the Zope application is still healthy. Defaults to `1` second.

