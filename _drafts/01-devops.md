---
layout: post-text
title: How I DevOps
tags: devops, gitlab, saltstack
---

So apparently the developer infrastructure I created at work is interesting to people.

The two biggest pieces we're using are on-prem GitLab and SaltStack.

GitLab is a lot like GitHub and BitBucket, but the thing I really like about it is that the self-hosted packages also has a well-integrated and quite flexible automatic build system (GitLab CI), static file hosting built from that (GitLab Pages), a concept of environments and deployments, and a bundle of project management stuff.

SaltStack is a centralized configuration management tool. Ok, that's how it's billed as. It's really an authenticated master/minion message bus that grew a command execution system that grew a state tool. That is, the configuration and server management is built on layers, and all those layers are available to you. These building blocks can be used not just for configuration management, but could also be used to create monitoring, autoscaling/autohealing, infrastructure querying, or just general eventing tools.

Standing these tools up is pretty standard. GitLab has Omnibus packages, SaltStack has bootstrap scripts and package repos. You can pretty easily get SaltStack to pull from GitLab by following https://docs.saltstack.com/en/latest/topics/tutorials/gitfs.html

API
===

I strongly recommend setting up salt-api. The default authentication for salt is... not great. Just set it up from the get-go and get used to using pepper (or [shameless plug] my rewrite of it cumin).

Just be sure to enable anonymous webhooks, for reasons below.

CI
==

So the first really interesting bit of integration I did was to enable GitLab CI to poke at SaltStack. This enables things like deploying via SaltStack.

1. Set up a GitLab CI runner on the Salt Master. Use the shell executor and give it a tag (eg, salt)
2. Configure the runner in GitLab so it only executes jobs specifically tagged for it
3. On the Salt Master, create a script `salt-orchestrate` to run `salt-run state state.orchestrate $*`
4. Give all users (or at least the runner user) passwordless sudo access to salt-orchestrate

Basically, this creates a way for CI to run salt scripts (orchestration) without you having to give CI total access to all of your infrastructure.

As a note, a minion will only do one state operation at a time, especially highstates. So if multiple projects (say, a frontend and a backend) deploy to the same minion, you can run their deploy jobs at the same time. The way I avoid this is that I configure the salt-master CI runner to only run one job at a time. It makes it a bottle-neck, because pretty much any salt-related job has to go through it, but it effectively makes that safe.

The Salt Repo
-------------

Keeping the salt state files means you have access to CI. Which means you can take action whenever changes happen. There's two things I recommend:

* Update the saltfs. it caches for ~10min, so having CI explicitly clear this cache is a serious quality-of-life boost. https://github.com/whytewolf/salt-phase0-orch/blob/master/orch/sys/salt/update.sls
* Run a highstate. This really depends on how you decided to handle how and when to highstate. Since I highstate as part of the CI deploy (I also get the results of the highstate and its success as part of the build and exposed in GitLab), whenever I push to the salt repo, I highstate everything. This is also run nightly as a precautionary measure, to make sure servers don't drift.

WebHooks
========
I've found that having GitLab feed all of its webhooks to salt useful, because I then have events on the salt message bus whenever anything happens in GitLab, which is pretty much any developer activity.

It's pretty easy. Just add the salt-api webhook URL (you did set up salt-api, right?) to all your gitlab projects.

Oh, and I would write a bit of code to add this webook to new projects. This can be done from the salt reactor or as an independent microservice.

With this information, you can, for example, create a global build dashboard that works across all projects, without having to make sure each project has its webhook added. Just hook the dashboard up to the salt-api event stream, write a bit of javascript, and voila!
