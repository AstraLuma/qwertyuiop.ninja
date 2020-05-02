---
layout: post-text
title: Gamebear 1: Project Intro
tags: ppb, gamebear, raspberry pi
---

So I had an idea. What if we could take [PursuedPyBear](https://ppb.dev/) and stick it in a handheld? And make it easily editable by anyone we walked up to at a conference?

So imma make one!

Basically, take a Raspberry Pi 4, toss on some buttons, some speakers, a screen, and a battery. Give it a case. Write some software.

* Raspberry Pi 4: An SBC that has a reasonable processor, supports being a USB device, and has a pretty large ecosystem of accessories.
* Handheld kit: Waveshare has has a line of gamepi kits to do exactly what I want. The problem with these is that they were designed for the Raspberry Pi 3, not the Raspberry Pi 4. I do think it will mostly work, but I don't have one in-hand yet to try it.

The goal is to make a programmable handheld system that uses the ppb game engine but has the user experience of CircuitPython--you plug it in, a drive pops up, you edit files live, and they take effect immediately. This is proven to be Very Cool.

So how am I going to do this?

On the Raspberry Pi 4, the USB Type-C port used for powering the board can also act as a data port. (Earlier revisions had some problems with certain kinds of cables, but this one is working fine for all the cables I already had.) So we just need to teach linux how to be a file store.

There's two ways to store files over USB: Mass Storage (used by flash drives) and MTP (used by phones). Mass storage works like internal harddrives--with blocks and filesystems and stuff. Linux supports this just fine, but it is very hard to get two devices (the computer and the gamebear) to be able to read from the same "drive" without something getting corrupted. This leaves MTP, which is used by phones for the same reasons I'm using it. It works at the file level, actually sending file transfer commands instead of block-level reads and writes.

After you implement MTP and you have a directory full of data available over USB, you just need to write a file watcher and game reloader. I consider this bit to be fairly trivial.

One of the things I want to do is to be able to create a fully-baked image that doesn't require runtime configuration of the device. I think this will make it easier to make more repeatably and reliably.
