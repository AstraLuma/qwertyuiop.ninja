---
layout: post-text
title: Run a Runner on Codeberg
tags: 
excerpt_separator: <!--more-->
---

So you wanna make the jump to Codeberg, but aren't happy with their CI? Here's how to run your own!

<!--more-->


## Why

As I said [previously](/2026/02/17/forgejo-rtd.html):

> Microsoft/GitHub is making unpleasant and distasteful choices, and I would like off the ride please. Forgejo and Codeberg are currently a reasonable alternative--they're big weakness is CI/CD, but otherwise I find Codeberg solid for my open source work.

There's two specific problems with it:

1. The resources provisioned are pretty wimpy.
2. Building containers is explicitly prohibited.

Additionally, as I'm doing commercially sponsored open source (that is, I'm doing open source work as part of [Teahouse Hosting](https://counter.teahouse.cafe/r/qwertyuiop)), I figure I should bring my own CI resources.

Thankfully, bringing your own runners is convenient and well supported.


## What's Needed

Pretty much any always-on, always-connected computer will do it. Ideally, it should have a fast drive (CI speed is most impacted by drive speed, but there's a trick for that), and double-ideally pretty chunky (more cache space).

It needs to run Linux with Docker. The distro doesn't matter.

Note that each runner can only be registered to one scope--a user, an org, or a repo. If you want multiple scopes, you will need multiple runners, and adjust these instructions to handle that.


## The Start

The start of this follows along with the [OCI Image Installation instructions](https://forgejo.org/docs/next/admin/actions/runner-installation/#oci-image-installation), so we start with the compose YAML:


```yaml
version: '3.8'

services:
  docker-in-docker:
    image: docker:dind
    container_name: 'docker_dind'
    privileged: 'true'
    command: ['dockerd', '-H', 'tcp://0.0.0.0:2375', '--tls=false']
    restart: 'unless-stopped'

  runner:
    image: 'data.forgejo.org/forgejo/runner:12'
    links:
      - docker-in-docker
    depends_on:
      docker-in-docker:
        condition: service_started
    container_name: 'runner'
    environment:
      DOCKER_HOST: tcp://docker-in-docker:2375
    # User without root privileges, but with access to `./data`.
    user: 2000:2000
    volumes:
      - /var/lib/forgejo-runner:/data
    restart: 'unless-stopped'

    # Final, see Forgejo docs
    command: '/bin/sh -c "sleep 5; exec forgejo-runner daemon --config config.yml"'
```

I'm utilizing my [systemd-compose integration](https://gist.github.com/AstraLuma/d22c2ce78fb0744e469060dadf5020f7) (which is really another blog post) with this compose, which means it goes in `/etc/compose/forgejo-runner`.


## The Little Changes

A few things that this changes from the original:

First, the command uses `exec`. This is just habbit because containers can care what's PID 1 (something something signal forwarding or something).

Second, instead of using a compose-local data directory, I used `/var/lib/forgejo-runner`. This is more aligned with Linux file system norms, and will make future admin easier.

Third, I changed the UID/GID to 2000 to avoid colliding with any current or future human users.


## Registration

Registration is basically as trivial as it is in the instructions. Just pick the scope you want (server-wide is not an option on Codeberg), and give the runner the token.


### Choosing Tags

A critical part of the registration process is tags. You can update these later, but you do need to put some thought into this. [The docs](https://forgejo.org/docs/next/admin/actions/#choosing-labels) do discuss this, but not well.

A runner has one or more tags, and they're structured:

```
node20:docker://node:20-bookworm
^^^^^^ ^^^^^^   ^^^^^^^^^^^^^^^^-----default image
     |      +---virtualization system
     +---Arbitrary label
```

First, you'll probably want the `docker` virtualization system. `lxc` and `host` (aka none) are also options, but if you're not sure what you want, use `docker`.

The suggested images are ok, but if you want GitHub compatibility (which will make porting actions much easier), you'll want one of [the catthehacker images](https://github.com/catthehacker/docker_images). I'm using `ghcr.io/catthehacker/ubuntu:act-latest`, but this doesn't have full compatibility (I hit a problem where it doesn't have [Poetry](https://python-poetry.org/)). At the very least, you will need images with node installed for JavaScript actions to work.

The last bit is what labels you want to use to reference what workflows use what runners. These can be whatever (and I think different labels can lead to different environments). I used the hostname, `docker-build` (to identify who can build images), and the `codeberg-*` labels (so it'll also pick up jobs tagged for the standard runners).

Altogether, I ended up with this set:

* `<HOSTNAME>:docker://ghcr.io/catthehacker/ubuntu:act-latest`
* `docker-build:docker://ghcr.io/catthehacker/ubuntu:act-latest`
* `codeberg-tiny:docker://ghcr.io/catthehacker/ubuntu:act-latest`
* `codeberg-tiny-lazy:docker://ghcr.io/catthehacker/ubuntu:act-latest`
* `codeberg-small:docker://ghcr.io/catthehacker/ubuntu:act-latest`
* `codeberg-small-lazy:docker://ghcr.io/catthehacker/ubuntu:act-latest`
* `codeberg-medium:docker://ghcr.io/catthehacker/ubuntu:act-latest`
* `codeberg-medium-lazy:docker://ghcr.io/catthehacker/ubuntu:act-latest`

You could maybe set smaller images in the smaller tags, but Docker already shares base images between containers, so using more images might result in more resources, not less.


## Configuration

Under this configuration, you'll find the runner's `config.yml` under `/var/lib/forgejo-runner`. It should be in `/etc`, but I didn't feel like trying to move it.

First, set `runner.capacity`. I left mine as `1` because, again, low-powered box.

I wish I could set `container.enable_ipv6`, but I'm not set up for IPv6 containers, and that's an entire project on its own.

I suspect you should set `container.force_pull` and `container.force_build` to `true`. Docker's caches are pretty good, so these should be cheap if everything's working.

I would definitely leave `cache.enabled` as `true`; caching can make or break build times, and lots of ecosystem actions can use it.

Everything else should either be probably left alone (eg, `runner.file`) or adjusted to taste (eg, `runner.timeout`).


## Cleanup

I'm already running [a cleanup process](https://gist.github.com/AstraLuma/d22c2ce78fb0744e469060dadf5020f7#file-docker-prune-service) on the main Docker. But arguably more important is a regular cleanup on the dind instance.

(TODO: Do this)


## The Problem

Ok, so this works in the sense that it runs jobs, but it can't actually use Docker from within jobs, which is needed to build containers. Which is half the point of this exercise.

(Switch to unix domain socket, cross-mount it)

(config: `container.docker_host`, triple docker)


### A Trick

(Mount a tmpfs in dind, possibly even [zram](https://wiki.archlinux.org/title/Zram).)
