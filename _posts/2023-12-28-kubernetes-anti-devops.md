---
layout: post-text
title: "Is Kubernetes Anti-DevOps?"
tags: kubernetes, devops
---

Ok, so that title is a Spicy Hot Take:tm:, so let's break that down.

First, let's define DevOps. We're talking about DevOps, the practice.

DevOps looks to re-arrange how work is divided among several teams. The classical way being you have a development team and a systems adminstration team--the development team writes a bunch of code, hands it to the sysadmins figure out how the heck to get it onto boxen. DevOps looks to shuffle that into app and platform--the sys admins now provide a (nominally) self-service platform with the features needed to run an app, and developers use that to deploy their code. The thought is that the people creating problems are more likely to be bothered by them.

Which is good! The App/Platform model is pretty great. It reduces the scope of concern for the sys admins, it empowers the developers, and there's a lot more owning your stuff! Wins all around. But it assumes that your developers have enough knowledge about how the platform works that they can operate apps on it.

Which brings us to Kubernetes.

Have you tried teaching someone how to use Kubernetes? Have you tried to teach someone who doesn't have experience in containers, Linux, or just what goes into running a service? Maybe I'm unusual in finding Kubernetes to be A Lot, but I think it's A Lot, and I can't imagine teaching it to a junior. My industrial-automation-with-a-computer-habbit girlfriend is right out.

So, Kubernetes is hard and complicated. So what do you do when you have something hard and complicated? You bring in experts.

So you have Kubernetes experts, and you get things going, and your apps are purring and users are happy. But there's a problem. Have you spotted it?

Your developers are no longer operating their apps. They're writing their code and throwing it over the wall again! Except it's no longer the sys admins catching it, it's the SREs! Because Kubernetes is so complicated, so difficult to use, your developers aren't empowered. You just have more complicated ops.

So, at the end of this, Kubernetes is anti-devops. There's lots of fantastic work being done under the auspices of the CNCF, and more places than ever can make their own cloud magic. It's phenomenal! But I suspect if you tried to teach a common dev how to use it, it'd take you a while; they wouldn't be empowered, they'd just have a new specialty.