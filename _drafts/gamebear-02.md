---
layout: post-text
title: Gamebear 2: Building
tags: ppb, gamebear, raspberry pi
---

So, as part of [Gamebear](TODO), I want to use some software that's not part of the Raspbian package repositories, namely [uMTP-Responder](https://github.com/viveris/uMTP-Responder) and [gt](https://github.com/kopasiak/gt).

I also want to be able to create fully-baked images on my laptop.

And I find cross compiling fiddly and complicated.

So how do I conduct these builds?

Well, I have a spare Raspberry Pi 3 I'm not really using. And I do "devops", so I would like to do my builds in clean, fresh containers.

And I did write [this little project](https://buildahscript.github.io/) that was originally for more dynamic container building, but turns out is also pretty good for build systems. And I like containerized builds, so of course I'm going to look for excuses to use them.

Ok, so how do you build a project in a container on a remote system?

First of all, the build script. This is surprisingly short for all the features it provides.

```python
with Container('arm32v7/debian') as c:
    c.run(['apt-get', 'update', '-y'])
    c.run(['apt-get', 'install', '-y', 'git', 'libc-dev', 'gcc', 'g++', 'make', 'pkgconf'])
    c.run(['git', 'clone', 'https://github.com/viveris/uMTP-Responder.git', '/tmp/umtp'])
    c.workdir = '/tmp/umtp'
    c.run(['make', 'CFLAGS="-DUSE_SYSLOG"'])
    c.copy_out('/tmp/umtp/umtprd', 'umtprd')
```

Most of the hard work is being handled by buildahscript itself.

I did look into creating a "quick and dirty CI" that would allow defining these build jobs via YAML. When I made a working prototype, I found that it didn't really reduce the size of the build definition any, made expressing certain things more awkward, and I also had this new project to debug. So I binned it.

Ok, so how do I actually do the build? With SSH of course!

1. Copy the build script to the build pi
2. Run the build
3. Copy back the artifacts
4. Add artifacts to the image

The script I'm using goes like:

```sh
#!/bin/sh
set -e

HOST=$1

TMP=$(ssh $HOST mktemp -d)

scp buildscript.py $HOST:$TMP
ssh $HOST buildahscript-py $TMP/buildscript.py
scp $HOST:$TMP/{umtprd,gt.tar} .
ssh $HOST rm -r $TMP
```

This can be made more efficient with the use of [Paramiko](https://www.paramiko.org/) or using the `ControlMaster` OpenSSH option, but I'm keeping it simple for now.

So just run the above stuff and you're done, right?

Sure, if you're ok with a two-and-a-half-hour build time.

Ok, so first of all, I've only shown the build for [uMTP-Responder](https://github.com/viveris/uMTP-Responder). I'm also building [gt](https://github.com/kopasiak/gt) and its dependency [libusbgx](https://github.com/libusbgx/libusbgx).

Second of all, pretty much all of the time is spent installing build dependencies. And most of that time is spent installing TeX-related things, which is a dependency of asciidoc, which is used by gt to build man pages. One easy way is to just patch out the manpage building. But that's no fun.

So I'm going to spend the rest of this post talking about how I optimized this build.

The first step is to move all the apt operations to a common image.

```python
with Container('arm32v7/debian') as c:
    c.run(['apt-get', 'update', '-y'])
    c.run(['apt-get', 'install', '-y', 'git', 'libc-dev', 'gcc', 'g++', 'make', 'pkgconf'])
    img = c.commit()

with Container(img):
    c.run(['git', 'clone', 'https://github.com/viveris/uMTP-Responder.git', '/tmp/umtp'])
    c.workdir = '/tmp/umtp'
    c.run(['make', 'CFLAGS="-DUSE_SYSLOG"'])
    c.copy_out('/tmp/umtp/umtprd', 'umtprd')
```

This will actually run slower because we're doing extra IO in the image/container churn, and IO on most Raspberry Pis are _slow_. But it also means we can cache the build image for reuse between runs.

So how do we cache the image? We're going to use the buildah image store to keep them, and craft a special tag with the packages we installed into the package.

```python
import hashlib

IMAGE_NAME = "gamebear-build"

def get_debian_with_packages(baseimage, pkgs):
    h = hashlib.sha256(' '.join(pkgs).encode('utf-8'))
    tag = f"{IMAGE_NAME}:{h.hexdigest()}"

    try:
        return Image(tag)
    except ImageNotFoundError:
        with Container(baseimage) as c:
            c.run(['apt-get', 'update', '-y'])
            c.run(['apt-get', 'install', '-y', *pkgs])
            img = c.commit()
            img.add_tag(tag)
            return img
```

To explain this:

1. Make a tag name. We use a hash of the list of packages, partly to limit the size of the tag, partly because package names can contain characters disallowed in container names
2. Look up the container
3. Build if not available

(Left as an excercise to the reader is to apply additional cache policies. Try `Image.inspect()`.)

So after all this, have we improved the build time?

Well, not the first one. That first one still takes two hours. But the second build only took ten minutes! That's a pretty nice improvement, although leaves something to be desired.


The final script looks like:

```python
#!/usr/bin/env buildahscript-py
import hashlib
from pathlib import Path

IMAGE_NAME = "gamebear-build"

output = Path(__file__).resolve().parent


def get_debian_with_packages(baseimage, pkgs):
    h = hashlib.sha256(' '.join(pkgs).encode('utf-8'))
    tag = f"{IMAGE_NAME}:{h.hexdigest()}"

    try:
        return Image(tag)
    except ImageNotFoundError:
        with Container(baseimage) as c:
            c.run(['apt-get', 'update', '-y'])
            c.run(['apt-get', 'install', '-y', *pkgs])
            # TODO: Annotations
            img = c.commit()
            img.add_tag(tag)
            return img


img = get_debian_with_packages('arm32v7/debian', [
    'git', 'libc-dev', 'gcc', 'g++', 'make', 'pkgconf', 'libconfig-dev',
    'autoconf', 'libtool', 'cmake', 'asciidoc',
])

with Container(img) as c:
    c.run(['git', 'clone', 'https://github.com/viveris/uMTP-Responder.git', '/tmp/umtp'])
    c.workdir = '/tmp/umtp'
    c.run(['make', 'CFLAGS="-DUSE_SYSLOG"'])
    c.copy_out('/tmp/umtp/umtprd', 'umtprd')

with Container(img) as c:
    c.run(['git', 'clone', 'https://github.com/libusbgx/libusbgx.git', '/tmp/libusbgx'])
    c.workdir = '/tmp/libusbgx'
    c.run(['autoreconf', '-i'])
    c.run(['./configure'])
    c.run(['make'])
    c.run(['make', 'install'])
    c.run(['tar', 'caf', '/tmp/usbgx.tar', '/usr/local'])
    c.copy_out('/tmp/usbgx.tar', output / 'usbgx.tar')

with Container(img) as c:
    c.copy_in('usbgx.tar', '/tmp/usbgx.tar')
    c.run(['tar', 'xaf', '/tmp/usbgx.tar'])
    c.run(['git', 'clone', 'https://github.com/kopasiak/gt.git', '/tmp/gt'])
    c.workdir = '/tmp/gt'
    c.run(['cmake', '-DCMAKE_INSTALL_PREFIX=/usr/local/', './source/'])
    c.run(['make'])
    c.run(['make', 'install'])
    c.run(['mv', '/usr/local/usr/share', '/usr/local/share'])  # https://github.com/kopasiak/gt/issues/15
    c.run(['tar', 'caf', '/tmp/gt.tar', '/usr/local'])
    c.copy_out('/tmp/gt.tar', output / 'gt.tar')
```