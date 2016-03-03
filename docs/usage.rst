Using this image
================
There are two ways to use this image out-of-the-box:

1. Standalone
2. ZEO client

1. Simple usage
---------------
::

  $ docker run -p 8080:8080 plone/plone

Now, ask for http://localhost:8080/ in your workstation web browser,
and add a Plone site.

2. ZEO client
-------------

Considering ZEO server is running at `192.168.1.1` on default port `8100`::

  $ docker run -e ZEO_ADDRESS=192.168.1.1:8100 -p 8080:8080 plone/plone

Now, open http://localhost:8080/ in your workstation web browser. If you
already have a Plone site within ZEO database, click on `View your Plone site`,
otherwise add a new one.

3. Scale
--------
In order to scale up and down the number of ZEO clients you'll need
orchestration tools like `docker-compose <http://docs.docker.com/compose/install/>`_

Bellow is a `docker-compose.yml` example with ZEO server and Plone
instance configured as a ZEO client::

  haproxy:
    image: eeacms/haproxy
    ports:
    - 8080:5000
    - 1936:1936
    links:
    - plone
    environment:
    - BACKENDS_PORT=8080
    - SERVICE_NAMES=plone

  plone:
    image: plone/plone
    links:
    - zeoserver
    environment:
    - ZEO_ADDRESS=zeoserver:8100

  zeoserver:
    image: plone/zeoserver

Start cluster::

  $ docker-compose up -d

Scale the number of ZEO clients::

  $ docker-compose scale plone=4

Now, open http://localhost:8080 in your workstation web browser. To see the
HAProxy backends health, go to http://localhost:1936 Default user: `admin/admin`

4. Debug mode
-------------
You can also start Plone in debug mode (fg) by running::

    $ docker run -p 8080:8080 plone/plone fg

Still, this will not allow you to add `pdb` breakpoints. For this, you'll have
to run Plone inside container like::

    $ docker run -it -p 8080:8080 plone/plone bash
      $ bin/instance fg

5. Add-ons
----------
You can easily test new or existing Plone add-ons by passing them via `BUILDOUT_EGGS`
environment variable::

    $ docker run -p 8080:8080 -e BUILDOUT_EGGS="plone.theme.spring plone.content.publication" plone/plone fg

The same way as above you can pass `BUILDOUT_ZCML` environment variable to include
custom ZCML files or `BUILDOUT_DEVELOP` environment variable to develop new or
existing Plone add-ons::

    $ docker run -p 8080:8080 \
                 -e BUILDOUT_EGGS="plone.theme.winter" \
                 -e BUILDOUT_DEVELOP="src/plone.theme.winter" \
                 -v $(pwd)/src:/plone/instance/src \
             plone/plone fg

Make sure that you have your Plone add-on code at `src/plone.theme.winter` and
that Plone user inside Docker container (`uid: 500`) has the rights to read/write there.

Running unit tests::

    $ docker run --rm -e BUILDOUT_EGGS="plone.app.testing plone.theme.winter" \
             plone/plone \
             bin/test plone.theme.winter

.. note::

  Please note that passing `BUILDOUT_` environment variables will slow down
  container creation as a buildout re-run inside container is triggered.
  Thus, we strongly recommend to use this only for testing or development purpose.
  For production use, create a new image as described in the next section.

6. Extending this image
-----------------------
In order to run Plone with your custom theme or Plone Add-ons, you'll have to
build another image based on this one. For this, you'll need to create two files,
`site.cfg` which is a `zc.buildout <https://pypi.python.org/pypi/zc.buildout/2.5.0>`_
configuration file, and `Dockerfile <https://docs.docker.com/engine/reference/builder/>`_
which is the Docker recipe for your image

site.cfg
~~~~~~~~
::

  [buildout]
  extends = buildout.cfg

  [instance]
  eggs += plone.awsome.addon

Dockerfile
~~~~~~~~~~
::

  FROM plone/plone:5

  COPY site.cfg /plone/instance/
  RUN bin/buildout -c site.cfg

Build your custom Plone image::

  $ docker build -t plone:custom .

Run it::

  $ docker run -p 8080:8080 plone:custom

Test it at http://localhost:8080

7. Environment Variables
------------------------

The Plone image uses several environment variable that allow to specify a more specific setup.

* `ZEO_ADDRESS` - This environment variable allows you to run Plone image as a ZEO client.
* `ZEO_READ_ONLY` - Run Plone as a read-only ZEO client. Defaults to `off`.
* `ZEO_CLIENT_READ_ONLY_FALLBACK` - A flag indicating whether a read-only remote storage should be acceptable as a fallback when no writable storages are available. Defaults to `false`.
* `ZEO_SHARED_BLOB_DIR` - Set this to on if the ZEO server and the instance have access to the same directory. Defaults to `off`.
* `ZEO_STORAGE` - Set the storage number of the ZEO storage. Defaults to `1`.
* `ZEO_CLIENT_CACHE_SIZE` - Set the size of the ZEO client cache. Defaults to `128MB`.
* `BUILDOUT_EGGS` - Customize Plone via Plone add-ons using this environment variable.
* `BUILDOUT_ZCML` - Include custom `ZCML` files.
* `BUILDOUT_DEVELOP` - Develop new or existing Plone add-ons.


8. Where to Store Data
----------------------

.. note::

  There are several ways to store data used by applications that run in
  Docker containers. We encourage users of the `plone` images to familiarize
  themselves with the options available.

The Docker documentation is a good starting point for understanding the different
storage options and variations, and there are multiple blogs and forum postings
that discuss and give advice in this area.

8.1 Data-only containers (suitable for production use)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Let Docker manage the storage of your database data `by writing the database files to disk on the host system using its own internal volume management <https://docs.docker.com/engine/userguide/containers/dockervolumes/#creating-and-mounting-a-data-volume-container>`_.
The advantages of this approach is that you can deploy your Plone stack anywhere,
without having to prepare hosts in advance or care about read/write permission
or selinux policy rules. The downside is that the files may be hard to locate
for tools and applications that run directly on the host system,
i.e. outside containers.

* Create the data container::

    $ docker run --name plone_data \
                -v /data/blobstorage \
                -v /data/filestorage \
             busybox chown -R 500:500 /data

* Use data container with Plone::

    $ docker run --name plone_one \
                 --volumes-from plone_data \
                -p 8080:8080 \
             plone

Or with `Docker Compose <https://docs.docker.com/compose>`_

* Add docker-compose.yml file::

    plone:
      image: plone
      volumes_from:
      - plone_data
      ports:
      - "8080:8080"

    plone_data:
      image: busybox
      volumes:
      - /data/filestorage
      - /data/blobstorage
      command: ['chown', '-R', '500:500', '/data']


* Start Plone stack::

    $ docker-compose up


8.2 Mount host directories as data volumes (suitable for development use)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create data directories on the host system (outside the container) and `mount these to a directory visible from inside the container <https://docs.docker.com/engine/userguide/containers/dockervolumes/#mount-a-host-directory-as-a-data-volume>`_.
This places the database files in a known location on the host system, and makes
it easy for tools and applications on the host system to access the files.
The downside is that the user needs to make sure that the directory exists,
and that e.g. directory permissions and other security mechanisms
on the host system are set up correctly.

* Create a data directories on a suitable volume on your host system, e.g. `/path/to/filestorage` and `/path/to/blobstorage`
* Start your `plone` container like this::

    $ docker run -v /path/to/filestorage:/data/filestorage -v /path/to/blobstorage:/data/blobstorage -d plone

The `-v /path/to/filestorage:/data/filestorage` part of the command
mounts the `-v /path/to/filestorage` directory from the underlying host system
as `/data/filestorage` inside the container, where Plone will
look for/create the `Data.fs` database file.

The `-v /path/to/blobstorage:/data/blobstorage` part of the command
mounts the `-v /path/to/blobstorage` directory from the underlying host system
as `/data/blobstorage` where blobs will be stored.

Make sure that Plone has access to read/write within these folders::

    $ chown -R 500:500 /path/to/filestorage /path/to/blobstorage

Note that users on host systems with SELinux enabled may see issues with this.
The current workaround is to assign the relevant SELinux policy type to the
new data directory so that the container will be allowed to access it::

    $ chcon -Rt svirt_sandbox_file_t /path/to/filestorage /path/to/blobstorage
