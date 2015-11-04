---
layout: post-text
title: Utilizing the 'z' Plugin for GUI Good
tags: i3, zsh, oh my zsh, dmenu
---

As part of [Oh My ZSH](http://ohmyz.sh/), there is a plugin called [`z`](https://github.com/rupa/z/) 
(repackaged from elsewhere). Basically, it maintains a list of the most popular 
directories you `cd` to and lets you jump to them quickly.

I thought to myself, "Self, I could use this to make a list of places I'd like to open a terminal in."
And so I answered myself, "Self, that's a great idea."

The [actual implementation of this turns out to be pretty simple](https://github.com/astronouth7303/.i3/blob/master/zmensh). 
It uses standard unix commands to pipe to `dmenu` to do the prompting, and hand it off to `i3-sensible-terminal`. Just 
add some z-related and Presto! It takes more space to describe than to just show you. Go on, click the link. I'll wait.

I'm using this every day and recommend it to anyone with a similar mix.
