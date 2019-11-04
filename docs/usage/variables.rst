===============================
Supported Environment Variables
===============================

.. note::

   Using environment variables requires advanced knowledge of Plone.

For Basic Usage
===============

* ``ADDONS`` - Customize Plone via Plone add-ons using this environment variable
* ``ZEO_ADDRESS`` - This environment variable allows you to run Plone image as a ZEO client.
* ``SITE`` - Add Plone with this id to `Data.fs` on first run. If NOT provided, you'll have to manually add a Plone Site via web UI
* ``VERSIONS`` - Use specific versions of Plone Add-on or python libraries

For Advanced Usage
==================

Plone
-----

* ``PLONE_ADDONS``, ``ADDONS`` - Customize Plone via Plone add-ons using this environment variable
* ``PLONE_SITE``, ``SITE`` - Add Plone with this id to `Data.fs` on first run. If NOT provided, you'll have to manually add a Plone Site via web UI
* ``PLONE_VERSIONS``, ``VERSIONS`` - Use specific versions of Plone Add-on or python libraries
* ``PLONE_ZCML``, ``ZCML`` - Include custom Plone add-ons ZCML files
* ``PLONE_DEVELOP``, ``DEVELOP`` - Develop new or existing Plone add-ons

ZEO
---

* ``ZEO_ADDRESS`` - This environment variable allows you to run Plone image as a ZEO client.
* ``ZEO_READ_ONLY`` - Run Plone as a read-only ZEO client. Defaults to `off`.
* ``ZEO_CLIENT_READ_ONLY_FALLBACK`` - A flag indicating whether a read-only remote storage should be acceptable as a fallback when no writable storages are available. Defaults to `false`.
* ``ZEO_SHARED_BLOB_DIR`` - Set this to on if the ZEO server and the instance have access to the same directory. Defaults to `off`.
* ``ZEO_STORAGE`` - Set the storage number of the ZEO storage. Defaults to `1`.
* ``ZEO_CLIENT_CACHE_SIZE`` - Set the size of the ZEO client cache. Defaults to `128MB`.
* ``ZEO_PACK_KEEP_OLD`` - Can be set to false to disable the creation of .fs.old files before the pack is run. `Defaults to true`.
* ``HEALTH_CHECK_TIMEOUT`` - Time in seconds to wait until health check starts. Defaults to `1` second.
* ``HEALTH_CHECK_INTERVAL`` - Interval in seconds to check that the Zope application is still healthy. Defaults to `1` second.

CORS
----

* ``CORS_ALLOW_ORIGIN`` - Origins that are allowed access to the resource. Either a comma separated list of origins, e.g. `http://example.net,http://mydomain.com` or `*`. Defaults to `http://localhost:3000,http://127.0.0.1:3000`
* ``CORS_ALLOW_METHODS`` - A comma separated list of HTTP method names that are allowed by this CORS policy, e.g. `DELETE,GET,OPTIONS,PATCH,POST,PUT`. Defaults to `DELETE,GET,OPTIONS,PATCH,POST,PUT`
* ``CORS_ALLOW_CREDENTIALS`` - Indicates whether the resource supports user credentials in the request. Defaults to `true`
* ``CORS_EXPOSE_HEADERS`` - A comma separated list of response headers clients can access, e.g. `Content-Length,X-My-Header`. Defaults to `Content-Length,X-My-Header`
* ``CORS_ALLOW_HEADERS`` - A comma separated list of request headers allowed to be sent by the client, e.g. `X-My-Header`. Defaults to `Accept,Authorization,Content-Type,X-Custom-Header`
* ``CORS_MAX_AGE`` - Indicates how long the results of a preflight request can be cached. Defaults to `3600`
