---
layout: post-text
title: Video to Camera
tags: gstreamer, linux, scripts
---

So I've had the idea for a long time to write myself a little script that would configure VLC/Gstreamer/etc 
to pipe a video file in to [v4l2loopback](https://github.com/umlaeute/v4l2loopback) to expose it as a virtual
webcam. Then I can just "play" it in Google Hangouts and have virtual movie watching parties, without silly 
things like "Ok, everyone hit play on 3!"

Unfortunately, there's some issues, namely:

* VLC can't write to v4l2, can only read from it
* gstreamer 1.0 and v4l2loopback seem to have a [bug](https://github.com/umlaeute/v4l2loopback/issues/83)
* mplayer can only write to v4l2 with mpeg-encoded streams (???)

So that's currently blocked, unless I feel like doing some terrible work-arounds involving streaming gstreamer 1.0
to gstreamer 0.10. We'll see.
