![Build Status](https://github.com/Olevi-id/shibboleth-idp-dockerized/actions/workflows/dockerhub.yml/badge.svg)

## Overview

This is heavy handedly slimmed down image from Shibboleth Identity Provider software previously built based on [CSC fork](https://github.com/CSCfi/shibboleth-idp-dockerized) of original [Unicon image](https://github.com/Unicon/shibboleth-idp-dockerized) which has not been updated since.

Refer to [Dockerfile](https://github.com/Olevi-id/shibboleth-idp-dockerized/blob/master/Dockerfile) for details of current version. We do not promise active maintenance unless otherwise specifically agreed. If you find images lagging behind, please do update: 

<a href="https://github.com/Olevi-id/shibboleth-idp-dockerized/fork">
    <img src="https://misc.karilaalo.fi/pics/icons8-git.svg" />
</a>

Currently the purpose of this repository is to provide an image in [Dockerhub](https://hub.docker.com/r/klaalo/shibboleth-idp) that is somewhat automatically updated using [GitHub Actions](https://github.com/features/actions). I use it to develop Shibboleth IdP based services further.

You may find some other purpose. If you do, please [tell us](https://www.weare.fi/en/contact-page/) about it in some imaginative way!

## Supported tags

* 4.3.1.1
    * OIDC Common: 2.2.0
    * OIDC OP: 3.4.0
* 4.3.1
* 4.3.0

For additional older images not yet pruned, please see [Dockerhub tag listing](https://hub.docker.com/r/klaalo/shibboleth-idp/tags).

## Creating a Shibboleth IdP Configuration

The old mechanism of creating an IdP configuration has been removed from this image. Shibboleth Project doesn't yet maintain or support an official Docker Deployment method for the product, so you will need expertiese in the product to implement working installation using Docker anyhow. So basically what I'm saying is that don't rely on this image if you are not familiar with the Shibboleth product.

## Using the Image

On top of this image you will need something else, some other layer to configure it and make it runnable in your environment. If you only want to try or see it out, do:

    docker run --rm -p 8080:8080 --name shibboleth-idp -it klaalo/shibboleth-idp

Then, optionnally, access the container with:

    docker exec -it shibboleth-idp /bin/bash

### Do not run Jetty as root

There has been consideration wether this basic image should have `USER jetty` [instruction](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user) included. Currently it is a deliberate decision to leave it out from this base image. However, this can not be emphasized too much, hence, we will repeat it:

**DO NOT RUN Jetty as ROOT**

Some argumentation and reasoning behind our decision for not including root privilege revocation during base image build can be found in previously linked [Docker reference](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user). Make note also that Jetty base image does not do privilege revocation, but leaves that for user discretion (see section Security in image [reference](https://hub.docker.com/_/jetty/)).

To make this sink in we say also this again: you need to implement another layer on top of this image before deploying the service to production use in your case and your environment. At that layer at latest you should apply some mechanism to enforce [least privilege principle](https://en.wikipedia.org/wiki/Principle_of_least_privilege). It may very well be that you need to fork our example of image build and better suit it to your needs to meet another Docker best practice that suggests to [minimise the layers](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#minimize-the-number-of-layers) in Docker images.

Few other references for your convenience:
* [OWASP Community Access Control guideline](https://owasp.org/www-community/Access_Control)
* [CISA Essentials Starter Kit](https://www.cisa.gov/sites/default/files/publications/Cyber%20Essentials%20Starter%20Kit_03.12.2021_508_0.pdf)
* [NIST 80-53r5](https://csrc.nist.gov/CSRC/media/Projects/risk-management/800-53%20Downloads/800-53r5/SP_800-53_v5_1-derived-OSCAL.pdf)
* [VAHTI 1/2013 SNT-011](https://www.suomidigi.fi/sites/default/files/2020-06/Vahti_ohje_1_2013_pdf_0.pdf)

### TLS not included

TLS support was removed. It is assumed that the container is not exposed in naked to the Internet, but instead the service is being run behind a load balancer offloading the TLS. To this end, `http2` module was removed in the builder script and respectively `http-forwarded` was added to facilitate necessities running behind a HTTP proxy.

## Authors/Contributors

This project was originally developed as part of Unicon's [Open Source Support program](https://unicon.net/support), which was funded by Unicon's program subscribers.

- John Gasper (<jgasper@unicon.net>)

Unicon discontinued to maintain this image. They were the first implementors on this.

- Sami Silén (<sami.silen@csc.fi>)

CSC guys have done quite a lot around this after Unicon.

- Juho Erkkilä (awesome devOps automation pipeline guru in Weare)

Juho has done lot of work in improving the [Dockerfile](https://github.com/Olevi-id/shibboleth-idp-dockerized/blob/master/Dockerfile)

- Kari Laalo (you know how to reach me)

I just try to glue things together somehow

### Credits

* Social preview image in Github [Photo by Philipp Katzenberger in Unsplash](https://unsplash.com/ko/@fantasyflip?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
* <a target="_blank" href="https://icons8.com/icon/16335/git">Git</a> icon by <a target="_blank" href="https://icons8.com">Icons8</a>  

## LICENSE

This has come quite far from original Unicon implementation, so I dared to alter this section. [See LICENSE file](https://github.com/Olevi-id/shibboleth-idp-dockerized/blob/master/LICENSE) for further details.