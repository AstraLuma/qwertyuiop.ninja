---
layout: post-text
title: "A PagerDuty Alaram Clock"
tags: raspberry pi, pagerduty
---

Two facts about me:

1. I have on-call shifts
2. I am a heavy sleeper

Seeing as it is not practical for me to be awake for my entire on-call shift,
this means I will sometimes receive pages when I am sleeping. And the PagerDuty
mobile app provides no features that resemble alarm clocks. (eg, go until I shut
you up.)

I received two suggestions for handling this:

* Set up the PagerDuty app so it has alarms every minute for 10 minutes (or whatever).
* Have PagerDuty send an SMS to Twilio which will then take additional automation
  actions.

I hated both of these, and searching the Internet didn't turn up much in prior
art. (Seriously, I can't be the first person with this problem.)

So I [wrote my own](https://github.com/AstraLuma/pagerduty-clock-hack).

What I had going into this:

* A Raspberry Pi Zero W next to my bed acting as a "white" noise generator (if
  by "white" we mean "Star Trek Voyager")
* A static IPv4 allocation (AT&T fibre is kinda surprisingly awesome)
* A robust home network
* Strong working knowledge of HTTP and Webhooks

In addition to the ~140 lines of Python, that Pi0 is running 
[Caddy](https://caddyserver.com/) and has been port forwarded 80 and 443 by my 
router. I'll often employ Hypercorn as the direct HTTP daemon, but with the HTTP
scraping that happens constantly and the computer power of a Pi0, I figured 
putting a high-performance httpd in front of the Python was a good idea. Plus, I
got HTTPS for free.

The app itself just wait for PagerDuty webhook calls and updates its copy of the
incidents. Then, it counts the number of unacknowledged (`triggered`) incidents
and turns a sound on or off based on that count. It uses 
[VLC](https://www.videolan.org/vlc/) for playback, and I stole the chime sound
from the PagerDuty mobile app.

The fun bit about this is that I figured out it needs no UI. It goes off when an
Incident is Assigned to you, and it turns off when you Acknowledge it. I didn't
need to code up a Snooze button or make a web page or anything.

I'm almost kinda wondering if there's a market opportunity here. (Not for me, I
don't know the first thing about shipping physical products. And frankly, I'd
rather not.)
