Docker Image for Plone 5
========================


Iterations
----------

[ ] Monolitic
[ ] With zeo
[ ] Run as user


How to use
----------

docker run -it plone/plone:latest

How to extend (no need to compile c)
------------------------------------

You need to files : mysite.cfg and Dockerfile on a folder

mysite.cfg

[buildout]
extends = buildout.cfg
eggs += myegg

Dockerfile

FROM plone/plone

COPY mysite.cfg /plone/mysite.cfg
WORKDIR /plone
RUN ./bin/buildout -v -c mysite.cfg
