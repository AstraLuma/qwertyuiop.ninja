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

And I did write [this little project](https://buildahscript.github.io/) that was originally for more dynamic container building, but turns out is also pretty good for build systems.

Ok, so how do you build a project in a container on a remote system?

First of all, the build script. This is surprisingly short for all the features it provides.

```python
with Container('debian') as c:
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

TODO: the actual script doing the ssh builds
