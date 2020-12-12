=======
RestAPI
=======

You can easily start a testing Plone backend for your custom front-end, RestAPI ready, by passing ``PLONE_SITE`` environment variable.

.. code-block:: shell

   docker run -p 8080:8080 -e PLONE_SITE=Plone plone


.. code-block:: shell

   curl -i http://localhost:8080/Plone -H 'Accept: application/json'

The server will then respond with the portal root in the JSON format:

.. code-block:: shell

    HTTP/1.1 200 OK
    Content-Length: 1322
    Content-Type: application/json
    Date: Mon, 04 Nov 2019 16:22:50 GMT
    Server: waitress
    Via: waitress
    X-Frame-Options: SAMEORIGIN
    X-Powered-By: Zope (www.zope.org), Python (www.python.org)

    {
    "@components": {
        "actions": {
        "@id": "http://localhost:8080/Plone/@actions"
        },
        "breadcrumbs": {
        "@id": "http://localhost:8080/Plone/@breadcrumbs"
        },
        "navigation": {
        "@id": "http://localhost:8080/Plone/@navigation"
        }
    },
    "@id": "http://localhost:8080/Plone",
    "@type": "Plone Site",
    "description": "",
    "id": "Plone",
    "is_folderish": true,
    "items": [
        {
        "@id": "http://localhost:8080/Plone/front-page",
        "@type": "Document",
        "description": "Congratulations! You have successfully installed Plone.",
        "review_state": "published",
        "title": "Welcome to Plone"
        },
        {
        "@id": "http://localhost:8080/Plone/news",
        "@type": "Folder",
        "description": "Site News",
        "review_state": "published",
        "title": "News"
        },
        {
        "@id": "http://localhost:8080/Plone/events",
        "@type": "Folder",
        "description": "Site Events",
        "review_state": "published",
        "title": "Events"
        },
        {
        "@id": "http://localhost:8080/Plone/ana-are-mere",
        "@type": "Folder",
        "description": "",
        "review_state": "published",
        "title": "Ana are mere"
        }
    ],
    "items_total": 4,
    "parent": {},
    "tiles": {},
    "tiles_layout": {},
    "title": ""

See more about `Plone RestAPI <https://plonerestapi.readthedocs.io/en/latest/>`_

CORS Configuration
==================

If you use CORS and want to make it work with `TUS <https://tus.io/>`_, you have to make sure the TUS specific HTTP headers are allowed by your CORS policy.

.. code-block:: shell

   docker run -p 8080:8080 \
              -e PLONE_SITE=Plone \
              -e CORS_ALLOW_ORIGIN="http://example.net"
          plone

See http://tus.io/protocols/resumable-upload.html#headers for a list and description of the individual headers.

Supported CORS environment variables
------------------------------------

* ``CORS_ALLOW_ORIGIN`` - Origins that are allowed access to the resource. Either a comma separated list of origins, for example `http://example.net,http://mydomain.com` or `*`. Defaults to `http://localhost:3000,http://127.0.0.1:3000`
* ``CORS_ALLOW_METHODS`` - A comma separated list of HTTP method names that are allowed by this CORS policy, for example `DELETE,GET,OPTIONS,PATCH,POST,PUT`. Defaults to `DELETE,GET,OPTIONS,PATCH,POST,PUT`
* ``CORS_ALLOW_CREDENTIALS`` - Indicates whether the resource supports user credentials in the request. Defaults to `true`
* ``CORS_EXPOSE_HEADERS`` - A comma separated list of response headers clients can access, for example `Content-Length,X-My-Header`. Defaults to `Content-Length,X-My-Header`
* ``CORS_ALLOW_HEADERS`` - A comma separated list of request headers allowed to be sent by the client, for example `X-My-Header`. Defaults to `Accept,Authorization,Content-Type,X-Custom-Header`
* ``CORS_MAX_AGE`` - Indicates how long the results of a preflight request can be cached. Defaults to `3600`
