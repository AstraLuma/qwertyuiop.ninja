---
layout: post-text
title: Docker Ingress with Caddy
tags: homelab, docker, caddy
excerpt_separator: <!--more-->
date: 2026-07-23 12:00:01
---

Some things I like:

* Caddy
* Docker (well, containers at any rate)
* Having a little box of blinking lights in my basement
* Running my own services for personal use

<!--more-->

Part of what I need to do to run services at home is what's called "ingress":

* Route hostnames to the appropriate local service
* Handle TLS certificates
* Do so without exposing inner services or creating problems

I've decided to solve this by running Caddy inside my Docker and having a shared network connecting all the public-facing containers to it. (This is similar to how Docker Swarm does it.)


## Architecture

I'm building up my environment through a series of compose projects. I suggest putting them in a global directory: `/etc/compose` (used by my [systemd-compose bodge](https://gist.github.com/AstraLuma/d22c2ce78fb0744e469060dadf5020f7)) or `/opt/docker-configs` or whatever, one directory per project. 


## Compose

First: The compose file. 

```yaml
services:
  caddy:
    container_name: caddy
    build: .
    restart: always
    ports:
      - 80:80/tcp
      - 443:443/tcp
      - 443:443/udp
    volumes:
      - caddy-data:/data/caddy
    networks:
      - ingress

volumes:
  caddy-data:

networks:
  ingress:
    name: ingress
```

This is largely a straight-forward Caddy compose: 80/443 for HTTP(S) (UDP for HTTP/3), caddy-data volume for certs and other cache.

The interesting thing here is the definition of the `ingress` network: this is referenced by other compose projects.


## Dockerfile

This is also a pretty standard xcaddy setup.

```dockerfile
FROM caddy:builder AS builder

WORKDIR /project
RUN xcaddy build \
    --with github.com/caddy-dns/acmeproxy@v1.1.1

FROM caddy:latest

COPY --from=builder /project/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile

VOLUME /data/caddy
```

I do recommend just doing this from the get-go: You need to compile caddy to install any plugins, and any sufficiently advanced setup will have non-standard plugins.

As for the acmeproxy plugin I'm using, see [my post on acmeproxy](/2026/07/23/acmeproxy.html).

The one thing you may want to change is that I'm including the Caddyfile in the image build. You may not want to do this, in which case, add a bind mount to the volumes in the above compose file. (Tip: Don't bind mount the file directly, a bunch of editors will break that. Create a subdirectory and bind mount that.)

## Caddyfile

The actual Caddyfile is largely a matter of taste. It needs to container site entries for every container you're exposing, as well any options you want to add. (eg, logging, acme email, etc)

## Usage

For each service you expose, you'll need a compose project an a snippet of Caddyfile

The compose needs some specific invocations, which we can demonstrate with [testserver](https://github.com/httptoolkit/testserver):

```yaml
services:
  testserver:
    image: docker.io/httptoolkit/testserver
    container_name: testserver
    networks:
      - ingress
    restart: always
    extra_hosts:
      - "host.docker.internal:host-gateway"

networks:
  ingress:
    external: true
```

A few critical things:

* The external `ingress` network has to be declared---this will refer to the ingress network defined above
* Connect the web app to the `ingress` network
* Set `container_name:` on the web app---this must be unique to the server, and is used by the Caddyfile below
* `restart:` and `extra_hosts:` should be set as practice

The Caddyfile snippet is similarly straightforward:

```
http://test.qwertyuiop.home {
    reverse_proxy testserver:3000
}
```

* Use the above `container_name` as the host for `reverse_proxy`
  * Also, set the port correctly
* If this is private, you need to declare it as http or set up ACME DNS-01
* If your application needs additional configuration, do it here
* If you want to access your application by relative domain or by IP, be sure to add them
