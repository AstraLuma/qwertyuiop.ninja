---
layout: post-text
title: "Unholy: Design and Rationale"
tags: unholy, docker
---

So last month I published [Unholy](https://unholy.readthedocs.io/), a dev
containers implementation. "Dev containers" meaning that some or all of your
development environment exists in a container.

Depending on your situation, you might like this for one or more reasons:

- Formal script for setting up a development environment
- Each project is encapsulated in its own space
- You can easily spin up environments in a shared hosting space
- Make remote development easier

## Prior Art

So this isn't a new idea--Docker Desktop itself ~has~had
[a feature](https://docs.docker.com/desktop/dev-environments/) for it.
(Although it was never a particularly compelling feature, and they've recently
stopped development on it.) I'm going to go over some of the alternatives, to
provide context for my own decisions.

### Ad-Hoc

Of course, nothing in here is something you can't just bang together with shell
scripts. But depending on your opinions on user experience and how many people
you need to share it with, this may not be desirable.

The most common form of this is bind mounting your source into a container,
which is very common in the "scripting" worlds like Python. This makes it
easier to run a local copy of the service, including things like databases and
message queues, while maintaining helpful utilities like auto-reload.

The downside is that, depending on how many features you want, the scripts
supporting this might become brittle or very complicated.

#### Remote development

Many of the features can also be realized by just developing on a remote
box--either with a remote editor (vim or emacs over ssh, or remote X11, or
some specialized split editor) or with a local editor (over NFS or SFTP).

These setups come with their own advantages as well as their own limitations.
Usually either poor integration with the rest of your desktop (eg, clipboard
support) or you're still running your dev tools (compilers, linters, git) locally.

### Visual Studio Code

Probably most well known of having this feature explicitly is Visual Studio
Code. There are first party plugins to support
[dev containers](https://code.visualstudio.com/docs/devcontainers/containers)
and [remote development](https://code.visualstudio.com/docs/remote/remote-overview).

Using VSCode for this rubs me wrong for a few reasons, some technical, some
philosophical:

- You cannot have remote containers--VS Code uses bind mounts
- The number of base containers is pretty limited, and it was non-obvious to me
  what was the correct way to customize it, or even what should go in it
- Much of the code supporting this is Microsoft proprietary, and is not usable
  in any other context (eg, Codium or JetBrains)

### Cloud Based

There's a few providers looking to sell you cloud-based development
environments. I like the idea of this, but honestly I don't like the idea of
paying a subscription fee to do my development.

There's a few public offerings for this that I'm aware of:

- [GitHub Codespaces](https://github.com/features/codespaces)
- [Gitpod](https://www.gitpod.io/)
- [Coder](https://coder.com/)

I thought these were all web based using a variant of VSCode, but I found out
that [JetBrains also supports this](https://www.jetbrains.com/remote-development/)
while researching this blog post.

From a technical perspective, I have no complaint about these products--their
limitations are pretty much the same as Unholy's, so I don't think they're a
big deal.

### JetBrains

I actually didn't know this until I thought to check because of the above, but
JetBrains does support the same dev containers spec that VSCode supports.

Microsoft has actually tried to publish it
[as a specification](https://containers.dev/), like Docker and Compose. I'm
skeptical on the "independent specification" front, but there's at least a
pile of alternate implementations.

This is where the writing process kinda falls apart, because this discovery
kinda invalidates some of the points made in the VSCode section, and I honestly
didn't know any of this until after I wrote Unholy and started on this blog
post. And I don't feel like actually editing this for consistency.

## Goals

Ok, given all of that (honestly mostly my experience with VSCode), let's discuss
what I wanted to do with Unholy:

- Support remote and local equally--you should be able to use whatever box is
  most convenient for the project
- Have a format I could easily teach others
- Support a variety of bases
- All the development tools in the development environment, including editor
  support tools
- Integrate with Docker Compose
- Gracefully handle environment rebuilds: you should be able to just rebuild
  the environment from config and pick up where you left off
- Minimize the amount of mandatory infrastructure or open ports (security
  surfaces)

## The Architecture

A lot of this is also discussed
[in the Unholy docs](https://unholy.readthedocs.io/en/stable/discussions/overview.html).

I'm going to be targetting Docker because there's not a lot of desktop-scale
container tools, and my experience with Podman says that it's not the drop-in
replacement you'd hope. Plus, Docker Destkop _largely_ just works.

Because of the remote requirement, bind mounts are out. And we can't just keep
it in the container because we want the container to be disposable. So we gotta
keep it in a volume.

On the config file front, do you know what's really easy to teach? Shell
scripts. I mean, not _that_ easy, it's a pretty quirky language. But its a
common and transferable skill. And TOML is pretty good (at least less footguns
than YAML), so I just kinda mushed them together in a common way: a script with
TOML front matter (see
[the Unholy docs](https://unholy.readthedocs.io/en/stable/discussions/unholyfile.html)).

This actually gives me a lot of flexibility. Source code in a volume means you
can mount it in other containers. You can have the dev container join any
compose-defined networks. You can take advantage of any Docker volume or
network plugins (if they existed). In theory, you could use a fleet through
Swarm.

On the editor front, we need something with remote UI features. That way, we can
put the editor core in the development environment with the dev tools, and
connect that to the UI. Anything web-based would work, but that makes me feel
weird; I know there's a lot of capability there, but in a post-Electron world
I don't love it. Neovim also supports this kind of split-head features, and I've
been on a vim kick.

So how do we connect everything? SSH is pretty secure, and has rich built-in
authentication. And you can connect to a Docker daemon over SSH. Plus, you can
do stdio pass through with Docker, even over any of the remote forward
protocols (even if the daemon is running behind a bastion host, in a firewalled
environment, or any other shenanigans you care to get up to).

As some odds-and-ends, we need to helpfully wire up SSH for git-over-SSH. So
lets make sure the user's SSH agent is forwarded, and grab their known hosts.
(I prefer SSH to HTTP for git because authentication is simpler to me, and
the forwarding is _definitely_ more straight forward.)

## Ok, So How Does it Work?

To bring it together:

You have an Unholyfile like this:

    ---
    [dev]
    image = "python:3"
    ---
    #!/bin/sh
    set -e
    pip install -r requirements.txt
    pip install pytest

You can immediately use this (with a compose file) to stand up a local container
with `unholy new <git repo URL>`. `unholy shell` and `unholy neovide` will get
you access to it.

If you used an SSH git URL, you should be able to perform git operations, thanks
to excessive and potentially unwise amounts of socat. (You wanna know what
"unwise" amounts of socat look like?
[Here you go](https://github.com/AstraLuma/unholy/blob/0c1558114f97e2062fb8db6052c4bb33d825d1de/unholy/compose.py#L426-L452).)

Neovim forwarding uses a similar technique, but instead of forwarding a socket
by use of socat, we just send that directly over stdio with the help of a
temporary script--Unholy writes out a Docker invocation to a file, and has
Neovide use that as its Neovim binary.

Something not mentioned so far: Developers have Opinions:tm:, and if you're on a
team, you'll have multiple opinions. So it's important to have project-specific
settings to cover things like "here's our testing and lint tools" but also you
need user settings for things like "I really like ripgrep" or "here's my vimrc".
(If you've never tried using someone else's vimrc, don't.) Unholy handles this
by supporting multiple Unholyfiles sourced from both the User's local machine
and from the project repo.

## You made it this far?

Please try out Unholy. Or leave a comment on fedi.
