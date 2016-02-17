# plone.docker

[Plone](https://plone.org) is a free and open source content management system built on top of the Zope application server.


## Features

### Supported tags and respective `Dockerfile` links

- [`5.0.2`, `5.0`, `5`, `latest` (*5.0.2/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.0/5.0.2/debian/Dockerfile)
- [`4.3.7`, `4.3`, `4` (*4.3.7/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/4.3/4.3.7/debian/Dockerfile)
- [`5.0.2-alpine`, `5.0-alpine`, `5-alpine` (*5.0.2/alpine/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/5.0/5.0.2/alpine/Dockerfile)
- [`4.3.7-alpine`, `4.3-alpine`, `4-alpine` (*4.3.7/alpine/Dockerfile*)](https://github.com/plone/plone.docker/blob/master/4.3/4.3.7/alpine/Dockerfile)


## Usage

### Start a Plone instance

```console
$ docker run -p 8080:8080 plone/plone
```

This image includes `EXPOSE 8080` (the Plone port), so standard container linking will make it automatically available to the linked containers. Now you can add a Plone Site at http://localhost:8080 - default Zope user and password are `admin/admin`.

### Start Plone as a ZEO client

Considering ZEO server is running at `192.168.1.1` on default port `8100` you can do:

```console
$ docker run -e ZEO_ADDRESS=192.168.1.1:8100 -p 8080:8080 plone/plone
```

or, using the ZEO Docker Image:

```console
$ docker run --name=zeo plone/zeoserver
$ docker run --link=zeo -e ZEO_ADDRESS=zeo:8100 -p 8080:8080 plone/plone
```

### Start Plone in debug mode

You can also start Plone in debug mode (`fg`) by running

```console
$ docker run -p 8080:8080 plone/plone fg
```

For more information on how to extend this image with your own custom settings, adding more add-ons, building it or mounting volumes, please refer to our [documentation](https://github.com/plone/plone.docker/tree/master/docs).



## Documentation

Full documentation for end users can be found in the ["docs"]((https://github.com/plone/plone.docker/tree/master/docs) folder.
It is also available online at http://docs.plone.org/


## Contribute


- Issue Tracker: http://github.com/plone/plone.docker/issues
- Source Code: http://github.com/plone/plone.docker
- Documentation: http://docs.plone.org/

## Support


If you are having issues, please let us know at https://community.plone.org

## License

The project is licensed under the GPLv2.
