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

Thankfully, bringing your own runners is convenient and well supported. (But making them production grade is not well documented.)


### Woodpecker

I like the Woodpecker language and model more than Actions. Unfortunately:

* It was unusable from sometime in December until about 3 weeks ago (3.15.0) because of a [OAuth refresh token bug](https://github.com/woodpecker-ci/woodpecker/issues/5839)
* I want to specifically work with the Forgejo Actions OIDC features coming with v15, and that doesn't work with Woodpecker


## What's Needed

Pretty much any always-on, always-connected computer will do it. Ideally, it should have a fast drive (CI speed is most impacted by drive speed, but there's a trick for that), and double-ideally pretty chunky (more cache space).

It needs to run Linux with Docker. The distro doesn't matter.

Note that each runner can only be registered to one scope--a user, an org, or a repo. If you want multiple scopes, you will need multiple runners, and adjust these instructions to handle that.

You should read the [Forgejo docs](https://forgejo.org/docs/next/admin/actions/runner-installation/) first--there's a process to this, and this blog post does not discuss the entire process, just how I differed from it.


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

Second, the runner version is upgraded. 12.7.1 added some improved job cleanup, which I needed immediately. (Also, 12.5.0 added portions of the OIDC features that I'm desperately looking forward to.)

Third, instead of using a compose-local data directory, I used `/var/lib/forgejo-runner`. This is more aligned with Linux file system norms, and will make future admin easier.

Fourth, I changed the UID/GID to 2000 to avoid colliding with any current or future human users.


## Registration

Registration is basically as trivial as it is in the instructions. Just pick the scope you want (user, organization or repository; server-wide is not an option on Codeberg), and give the runner the token.


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


## The Problem

Ok, so this works in the sense that it runs jobs, but it can't actually use Docker from within jobs, which is needed to build containers. Which is half the point of this exercise.

If we look at the [config](https://code.forgejo.org/forgejo/runner/src/branch/main/internal/pkg/config/config.example.yaml), you'll note a `docker_host` option. This controls both where the runner finds the Docker daemon _and_ if it's given to jobs. 

In the case that your Docker daemon is listening on TCP (as the Forgejo docs suggest), this option doesn't seem to do anything for the job--I tried several configuration variations, and nothing seemed to change the job environment noticibly. So we're going to need to switch to a unix-domain socket.

You'll need to adjust your compose in a pile of ways, as noted below:

```yaml
services:
  docker-in-docker:
    image: docker:dind
    container_name: 'docker_dind'
    privileged: 'true'
    # Rewrite this--the group is the same as forgejo-runner
    command: ['dockerd', '--group', '2000']
    restart: 'unless-stopped'
    # Add this volume, so the socket is in both containers
    volumes:
      - varrun:/var/run

  runner:
    image: 'data.forgejo.org/forgejo/runner:12'
    # Remove the link
    depends_on:
      docker-in-docker:
        condition: service_started
    container_name: 'runner'
    # Remove the DOCKER_HOST environment variable
    # This is the group number you need in the docker invocation above
    user: 2000:2000
    volumes:
      - /var/lib/forgejo-runner:/data
      # Add this volume
      - varrun:/var/run
    restart: 'unless-stopped'

    command: <WHATEVER>

# Define the varrun volume
volumes:
  varrun:
```

With that, we can set `container.docker_host` to `"automount"` and docker-in-jobs starts working.

Alternatively, if you don't like that set up (you want to use Docker over TCP or SSH, you want to use a third container daemon, other esoterica), you can do everything manually with `container.options`.


## Cleanup

I'm already running [a cleanup process](https://gist.github.com/AstraLuma/d22c2ce78fb0744e469060dadf5020f7#file-docker-prune-service) on the main Docker. But arguably more important is a regular cleanup on the dind instance. A build box will go through a lot of images, and Docker by default doesn't get rid of old images.


I used this dockerfile:

```dockerfile
FROM docker.io/library/alpine
# If you have buildx
RUN --mount=type=cache,target=/var/cache,sharing=locked apk add supercronic docker-cli

# Be sure to randomize the schedule
# 168 hours is a week
COPY <<EOF /etc/crontab
16 10 * * * docker system prune --all --force --filter "until=169h"
EOF

CMD ["supercronic", "/etc/crontab"]
```

([supercronic](https://github.com/aptible/supercronic) is great, btw)

And I added this service to the compose:

```yaml
  cleanup:
    build:
      dockerfile: cleanup.Dockerfile
    volumes:
      - varrun:/var/run
    restart: 'unless-stopped'
```

You should probably read the prune docs and make your own decisions. I set mine to be pretty aggressive, because nobody wants to debug "why is this image fourteen months old".


## qemu

I've [blogged about the specifics before]({% post_url 2020-05-18-gamebear-25 %}), so I'll just summarize.

Be sure to install the `qemu-user-binfmt` (Debian) package on the host. This registers qemu as an interpreter for cross-platform binaries (eg, arm on amd64). Since this registers binfmt interpreters with the kernel, and those interpreters are statically linked, it works within containers and should work through docker-in-docker and into the jobs. This will save some time in some build pipelines, and doesn't require any additional state or configuration.


## Result

Teahouse Hosting is using this configuration for its CI/CD on Codeberg. It's proving to be faster than I was expecting, especially knowing it's got an AMD FX-8800P from 2015. But most importantly, it's going to enable doing more things automatically.

(I'll try to remember to update here with some time-based follow-up.)


## A Trick

In this configuration, the Docker daemon running jobs (aka dind) just uses ephemeral container storage for its images, containers, etc. If you want, you can mount a tmpfs here (which might improve performance) or put it in a volume (which would improve cache durability).

The standard data directory for Docker is `/var/lib/docker`. You could mount that whole thing, or YOLO it and try to mount specific subdirectories. If you're feeling extra spicy, use [zram](https://wiki.archlinux.org/title/Zram) with tmpfs to minimize disk hits. I'm not going to, because I'm running this on scavanged hardware with consumer levels of RAM.
