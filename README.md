> **NOTE**: Our images are excellent for test driving Plone, checking add-ons or as a base for development/theming. \
We **don't** recommended them for production!

# Plone

[Plone](https://plone.org) is a free and open source content management system built on top of the Zope application server.

## Features

- Images for Plone 5.x and Plone 4.x
- Enable add-ons via environment variables
- Choose between [Debian](https://www.debian.org/) or [Alpine](http://www.alpinelinux.org/) based images

> **NOTE**: **Python 2 based Docker images** are no longer supported by the [Docker Official Images](https://docs.docker.com/docker-hub/official_images/) \
If you need Python 2, you can use `plone/plone:5-python2` instead of `plone:5-python2`.

## Supported tags and respective `Dockerfile` links

- [`5.2.2-alpine`, `5.2-alpine`, `5-alpine`, `alpine` (*5.2.2/alpine/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.2/5.2.2/alpine/)
- [`5.2.2-python38`, `5.2.2`, `5.2`, `5`, `python38`, `latest` (*5.2.2/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.2/5.2.2/debian/Dockerfile)
- [`5.2.2-python37`, `5.2-python37`, `5-python37`, `python37` (*5.2.2/python37/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.2/5.2.2/python37/Dockerfile)
- [`5.2.2-python36`, `5.2-python36`, `5-python36`, `python36` (*5.2.2/python36/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.2/5.2.2/python36/Dockerfile)
- [`5.2.2-python2`, `5.2-python2`, `5-python2`, `python2` (*5.2.2/python2/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.2/5.2.2/python2/Dockerfile)
- [`5.1.6`, `5.1` (*5.1.6/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.1/5.1.6/debian/Dockerfile)
- [`5.1.6-alpine`, `5.1-alpine` (*5.1.6/alpine/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.1/5.1.6/alpine/Dockerfile)
- [`4.3.19`, `4.3`, `4` (*4.3.19/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/4.3/4.3.19/debian/Dockerfile)
- [`4.3.19-alpine`, `4.3-alpine`, `4-alpine` (*4.3.19/alpine/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/4.3/4.3.19/alpine/Dockerfile)

## Prerequisites

Make sure you have Docker installed and running for your platform.
You can download Docker from https://www.docker.com.

## Usage

Choose either single Plone instance or ZEO cluster.

> **NOTE**: It is inadvisable to use following configurations for production.

### Standalone Plone instance

Plone standalone instances are best suited for testing Plone and development.

Download and start the latest Plone 5 container, based on [Debian](https://www.debian.org/).

```shell
docker run -p 8080:8080 plone
```

This image includes `EXPOSE 8080` (the Plone port), standard container linking will make it automatically available to the linked containers.

You can add a Plone Site at http://localhost:8080 - default Zope user and password are **`admin/admin`**.

By using the `tags` listed above a Plone container with a different version can be downloaded and started.

The following command starts a Plone 4.3 container, based on [Alpine](https://alpinelinux.org/).

```shell
docker run -p 8080:8080 plone:4.3-alpine
```

### Plone as ZEO cluster

ZEO cluster are best suited for production setups, you will **need** a loadbalancer.

Start ZEO server in the background

```shell
docker run -d --name=zeo plone zeo
```

Start 2 Plone clients (also in the background)

```shell
docker run -d --name=instance1 --link=zeo -e ZEO_ADDRESS=zeo:8080 -p 8081:8080 plone
docker run -d --name=instance2 --link=zeo -e ZEO_ADDRESS=zeo:8080 -p 8082:8080 plone
```

### Start Plone in debug mode

You can also start Plone in debug mode (`fg`) by running

```shell
docker run -p 8080:8080 plone fg
```

Debug mode may be used with ZEO

```shell
docker run --link=zeo -e ZEO_ADDRESS=zeo:8080 -p 8080:8080 plone fg
```

For more information on how to extend this image with your own custom settings,
adding more add-ons, building it or mounting volumes,
please refer to our [documentation](https://docs.plone.org/manage/docker/docs/index.html).


## Supported environment variables

The Plone image uses several environment variable that allow to specify a more specific setup.

### For basic usage

* `ADDONS` - Customize Plone via Plone add-ons using this environment variable
* `ZEO_ADDRESS` - This environment variable allows you to run Plone image as a ZEO client.
* `SITE` - Add Plone with this id to `Data.fs` on first run. If NOT provided, you'll have to manually add a Plone Site via web UI
* `VERSIONS` - Use specific versions of Plone Add-on or python libraries

Run Plone and install two addons ([eea.facetednavigation](https://github.com/eea/eea.facetednavigation) and [collective.easyform](https://github.com/collective/collective.easyform).)

```shell
docker run -p 8080:8080 -e SITE="mysite" -e ADDONS="eea.facetednavigation collective.easyform" plone
```

To use specific add-ons versions:

```shell
 -e ADDONS="eea.facetednavigation collective.easyform" -e VERSIONS="eea.facetednavigation=13.3 collective.easyform=2.1.0"
```

RestAPI:

```shell
docker run -p 8080:8080 -e SITE=plone plone

curl -H 'Accept: application/json' http://localhost:8080/plone
```

### For advanced usage

**Plone:**

* `PLONE_ADDONS`, `ADDONS` - Customize Plone via Plone add-ons using this environment variable
* `PLONE_SITE`, `SITE` - Add Plone with this id to `Data.fs` on first run. If NOT provided, you'll have to manually add a Plone Site via web UI
* `PLONE_VERSIONS`, `VERSIONS` - Use specific versions of Plone Add-on or python libraries
* `PLONE_PROFILES, PROFILES` - GenericSetup profiles to include when `SITE` environment provided.
* `PLONE_ZCML`, `ZCML` - Include custom Plone add-ons ZCML files
* `PLONE_DEVELOP`, `DEVELOP` - Develop new or existing Plone add-ons
* `FIND_LINKS` - Add custom `find-links` to the buildout configuration
* `SOURCES` - Add custom `sources` to the buildout configuration

To add custom sources, the `SOURCES` env var needs to be a string containing a *comma*-separated list of sources.
This is different from the other environment variables described above, which are *space*-separated.

For example:

```shell
 -e SOURCES="plone.restapi = git https://github.com/plone/plone.restapi,plone.staticresources = git https://github.com/plone/plone.staticresources"
```

**ZEO:**

* `ZEO_ADDRESS` - This environment variable allows you to run Plone image as a ZEO client.
* `ZEO_READ_ONLY` - Run Plone as a read-only ZEO client. Defaults to `off`.
* `ZEO_CLIENT_READ_ONLY_FALLBACK` - A flag indicating whether a read-only remote storage should be acceptable as a fallback when no writable storages are available. Defaults to `false`.
* `ZEO_SHARED_BLOB_DIR` - Set this to on if the ZEO server and the instance have access to the same directory. Defaults to `off`.
* `ZEO_STORAGE` - Set the storage number of the ZEO storage. Defaults to `1`.
* `ZEO_CLIENT_CACHE_SIZE` - Set the size of the ZEO client cache. Defaults to `128MB`.
* `ZEO_PACK_KEEP_OLD` - Can be set to false to disable the creation of *.fs.old files before the pack is run. Defaults to true.

**CORS:**

* `CORS_ALLOW_ORIGIN` - Origins that are allowed access to the resource. Either a comma separated list of origins, for example `http://example.net,http://mydomain.com` or `*`. Defaults to `http://localhost:3000,http://127.0.0.1:3000`
* `CORS_ALLOW_METHODS` - A comma separated list of HTTP method names that are allowed by this CORS policy, for example `DELETE,GET,OPTIONS,PATCH,POST,PUT`. Defaults to `DELETE,GET,OPTIONS,PATCH,POST,PUT`
* `CORS_ALLOW_CREDENTIALS` - Indicates whether the resource supports user credentials in the request. Defaults to `true`
* `CORS_EXPOSE_HEADERS` - A comma separated list of response headers clients can access, for example `Content-Length,X-My-Header`. Defaults to `Content-Length,X-My-Header`
* `CORS_ALLOW_HEADERS` - A comma separated list of request headers allowed to be sent by the client, for example `X-My-Header`. Defaults to `Accept,Authorization,Content-Type,X-Custom-Header`
* `CORS_MAX_AGE` - Indicates how long the results of a preflight request can be cached. Defaults to `3600`

## Documentation

Full documentation for end users can be found online at [docs.plone.org](https://docs.plone.org/manage/docker/docs/index.html).

## Contribute

- Issue Tracker: http://github.com/plone/plone.docker/issues
- Source Code: http://github.com/plone/plone.docker
- Documentation: http://docs.plone.org/

## Support

If you are having issues, please let us know at https://community.plone.org

## License

The project is licensed under the GPLv2.
