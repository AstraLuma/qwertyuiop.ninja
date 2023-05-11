---
layout: post-text
title: "Bladework: BIOS Settings"
tags: bladework, framework, homelab, bios
---

So the Framework mainboard is really designed to be attached to a battery. It runs fine without one. But one of the quirks is that the RTC battery does _not_ last long, and it'll frequently loose its BIOS settings unless it's plugged in all the time.

So I'm writing down the settings I'm using for my bladework project, mostly for my own future reference.

* Advanced
  * Battery Charge limit: 60 (Reportedly, this improves the life of a mostly-unused battery. Dunno what the best value is yet.)
* Security
  * Secure Boot
    * Enforce Secure Boot: Disabled (Really critically important, neither PXE nor USB boot will work unless you set this.)
* Boot
  * Quick Boot: Disabled
  * Quiet Boot: Disabled
  * Network Stack: Enabled
  * PXE Boot capability: UEFI:IPv4/IPv6
  * Timeout: 5

This is a problem in part because they're currently in a lightly modified version of the first party 3D printed case, which doesn't have room for batteries or anything. I'm working on a new case that will also hold the battery and power puck.

PS: [netboot.xyz](https://netboot.xyz/) is great and you should think about adding it to your network.
