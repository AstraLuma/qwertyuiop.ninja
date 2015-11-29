---
layout: post-text
title: Emojis on Linux
tags: emoji, linux, ibus, smuxi
---

So one thing lead to another, and now I have the [UniEmoji](https://github.com/lalomartins/ibus-uniemoji)
input method installed. Which means I can now (sometimes) type "💩" without dropping into character map.

The changes to this were surprisingly simple. I just installed `ibus` from apt, and it installed itself 
into the standard Xsession startup. Install UniEmoji, restart, and bam! So far, dmenu and Sublime don't
seem to use ibus at all (dmenu is no surprise, Sublime is a disappointment), and Smuxi had odd issues with it.

Sublime 3 has no IBus support. This is a topic on the forums, with no comment on the author. There's a few 
extensions that kinda fix it, but nothing complete.

Smuxi would allow the UniEmoji input dialog to pop open, but hitting enter to actually insert the text 
fails. The root cause is that Smuxi swallows the key press event, which is what UniEmoji is listening for.

(TODO: How this got fixed.)
