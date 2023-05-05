---
layout: post-text
title: "Bladework: A Framework-based homelab blade server"
tags: bladework, framework, homelab
---

So I'm apparently the kind of sword lesbian that'll have two different blade projects running at once.

The first one is a custom lightsaber hilt, and I don't think there's much to write about here. If you know machining, you can just look at the drawing and go "oh, ok". If you don't know machining, there's several lovely YouTube channels you can binge to start building the mindset. Oh, and there's lightsaber combat communities. LEDs go brrr.

The other one I'm calling Bladework. It's basically a bunch of [Framework laptop bits](https://frame.work/) stacked up and masquerading as a blade server. Keep in mind that there's no high IO backplane, it's pretty expensive for the compute you get, and I'm going to be building all the mechanical bits.

So why do this? I don't know, it seems fun.

Ok, I'm building a homelab cluster because I want to learn about HA and clustering apps and container fabric systems. And not the kind of learning you get by following a blog post with a couple of VMs, but the kind of learning you get by running services and using those services and having to fix stuff when it breaks. I want experience, not a completion certificate.

So what am I going to be running? The Unifi controller, private git + pipelines, potentially configuration management godbox, maybe Home Assistant, maybe something Tailscale related. Maybe some game servers. Probably something knowledge-organization related.

There are some concrete advantages, though. Less heat and power draw. Hopefully less noise. Integrated per-blade UPS. Flexible IO and power supply options. Flexible layout options--the mainboard and battery are 5U when arranged vertically, but you could easily fit less if you only want a 1U or 2U.

And in the process I'm learning CAD and 3D printing.

Currently, I have just units without batteries, in a modified version of the [first-party case](https://github.com/FrameworkComputer/Framework-Laptop-13/tree/main/Mainboard/Printable%20Case). I set up my EdgeRouter with [netboot.xyz](https://netboot.xyz/docs/kb/networking/edgerouter), so working with metal will hopefully be a bit easier. I'm going to try to get them going with some initial configurations (Probably with [Babashka](https://github.com/aurynn/babashka)), and then figure out how I want to do Puppet (that's an entire other blog post).

Stay tuned for further updates. Hopefully.
