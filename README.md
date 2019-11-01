# Plone

[Plone](https://plone.org) is a free and open source content management system built on top of the Zope application server.


## Features

- Images for Plone 5.x and Plone 4.x
- Enable add-ons via environment variables
- Choose between [Debian](https://www.debian.org/) or [Alpine](http://www.alpinelinux.org/) based images


## Supported tags and respective `Dockerfile` links

- [`5.2.0`, `5.2`, `5`, `latest` (*5.2.0/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.2/5.2.0/debian/Dockerfile)
- [`5.2.0-alpine`, `5.2-alpine`, `5-alpine`, `alpine` (*5.2.0/alpine/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.2/5.2.0/alpine/Dockerfile)
- [`5.2.0-python2`, `5.2-python2`, `5-python2`, `python2` (*5.2.0/python2/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.2/5.2.0/python2/Dockerfile)
- [`5.1.6`, `5.1` (*5.1.6/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.1/5.1.6/debian/Dockerfile)
- [`5.1.6-alpine`, `5.1-alpine` (*5.1.6/alpine/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.1/5.1.6/alpine/Dockerfile)
- [`4.3.19`, `4.3`, `4` (*4.3.19/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/4.3/4.3.19/debian/Dockerfile)
- [`4.3.19-alpine`, `4.3-alpine`, `4-alpine` (*4.3.19/alpine/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/4.3/4.3.19/alpine/Dockerfile)


## Prerequisites

Make sure you have Docker installed and running for your platform. You can download Docker from https://www.docker.com.


## Usage

Choose either single Plone instance or ZEO cluster.

**It is inadvisable to use following configurations for production.**


### Standalone Plone Instance

Plone standalone instances are best suited for testing Plone and development.

Download and start the latest Plone 5 container, based on [Debian](https://www.debian.org/).

```console
$ docker run -p 8080:8080 plone
```

This image includes `EXPOSE 8080` (the Plone port), so standard container linking will make it automatically available to the linked containers. Now you can add a Plone Site at http://localhost:8080 - default Zope user and password are **`admin/admin`**.


### Plone As ZEO Cluster

ZEO cluster are best suited for production setups, you will **need** a loadbalancer.

Start ZEO server in the background

```console
$ docker run -d --name=zeo plone zeo
```

Start 2 Plone clients (also in the background)

```console
$ docker run -d --name=instance1 --link=zeo -e ZEO_ADDRESS=zeo:8080 -p 8081:8080 plone
$ docker run -d --name=instance2 --link=zeo -e ZEO_ADDRESS=zeo:8080 -p 8082:8080 plone
```

### Start Plone In Debug Mode

You can also start Plone in debug mode (`fg`) by running

```console
$ docker run -p 8080:8080 plone fg
```

Debug mode may also be used with ZEO

```console
$ docker run --link=zeo -e ZEO_ADDRESS=zeo:8080 -p 8080:8080 plone fg
```

For more information on how to extend this image with your own custom settings, adding more add-ons, building it or mounting volumes, please refer to our [documentation](https://docs.plone.org/manage/docker/docs/index.html).


## Supported Environment Variables

The Plone image uses several environment variable that allow to specify a more specific setup.

### For Basic Usage

* `SITE` - Add Plone within this id to `Data.fs` on first run. If NOT provided, you'll have to manually add a Plone Site via web UI (*v5.2+*)
* `ADDONS` - Customize Plone via Plone add-ons using this environment variable
* `ZEO_ADDRESS` - This environment variable allows you to run Plone image as a ZEO client.

Run Plone and install two addons (eea.facetednavigation and collective.easyform)

```console
$ docker run -p 8080:8080 -e SITE="mysite" -e ADDONS="eea.facetednavigation collective.easyform" plone
```

To use specific add-ons versions:

```console
 -e ADDONS="eea.facetednavigation==13.3 collective.easyform==2.1.0"
```

RestAPI:

```console
$ docker run -p 8080:8080 -e SITE=plone plone

$ curl -H 'Accept: application/json' http://localhost:8080/plone
```

### For Advanced Usage

* `PLONE_PROFILES, PROFILES` - GenericSetup profiles to include when `SITE` environment provided. (*v5.2+*)
* `PLONE_ZCML`, `ZCML` - Include custom Plone add-ons ZCML files
* `PLONE_DEVELOP`, `DEVELOP` - Develop new or existing Plone add-ons
* `ZEO_READ_ONLY` - Run Plone as a read-only ZEO client. Defaults to `off`.
* `ZEO_CLIENT_READ_ONLY_FALLBACK` - A flag indicating whether a read-only remote storage should be acceptable as a fallback when no writable storages are available. Defaults to `false`.
* `ZEO_SHARED_BLOB_DIR` - Set this to on if the ZEO server and the instance have access to the same directory. Defaults to `off`.
* `ZEO_STORAGE` - Set the storage number of the ZEO storage. Defaults to `1`.
* `ZEO_CLIENT_CACHE_SIZE` - Set the size of the ZEO client cache. Defaults to `128MB`.
* `ZEO_PACK_KEEP_OLD` - Can be set to false to disable the creation of *.fs.old files before the pack is run. Defaults to true.


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
