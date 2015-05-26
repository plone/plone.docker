============
Random notes
============

Dockerfile
==========

- as less layers as possible
- as small as possible

In order to archive that, we could/should:

- download all eggs as tar.gz and pipe them into a build aka a long chain command
- avoid doing ADD or COPY because this will add extra layers

Images
======

We know that Debian or Ubuntu based images are not the best ones [most suited] because there are huge.
Further on you always should use your self build image.
By importing/using images like *FROM ubuntu:trusty* you give away all your control, because you **do not know** how the image is build and what is in it.

We will compromise here, since that repo is meant as example and not for production and most people know *debian and ubuntu*. So **we will base** our examples on *official debian/ubuntu docker images*, but **we will** add to the docs, that you should never do that !.

Not perfect but all means.
