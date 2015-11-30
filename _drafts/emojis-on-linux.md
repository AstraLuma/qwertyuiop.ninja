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

Sublime 3 has no IBus support. This are a few topics on the forums, with no comment from the author. There's a few 
extensions that kinda fix it, but nothing complete.

Smuxi would allow the UniEmoji input dialog to pop open, but hitting enter to actually insert the text 
fails. The root cause is that Smuxi swallows the key press event, which is what UniEmoji is listening for. The
fix for this is surprisingly complex and non-trivial. And unfortunately, the explaination of which involves
a background in GTK. Especially since I've looked at the source code for 3 different projects, including GTK
itself, in order to understand the issue. This will be the subject of a future blog post, as there doesn't seem
to be an answer on the "right" way to do this.

In addition, there is [a standard](http://google-opensource.blogspot.com/2013/05/open-standard-color-font-fun-for.html)
for including full-color bitmaps in OTF/TTF fonts produced by Google, accepted by Microsoft, and supposedly 
implemented in FreeType. But either their reference font generators are broken, or there's some missing pieces.

![FruityGirl preview](/assets/posts/fruitygirl.png "Preview by Gnome Font Viewer")

But as long as you have the Symbola font installed, Unicode Emojis will probably render.
