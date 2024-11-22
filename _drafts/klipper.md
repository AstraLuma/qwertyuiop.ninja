---
layout: post-text
title: Ender 3 S1 and Klipper
---

Earlier this year, MicroCenter had a sale on the Ender 3 S1. My girlfriend with a chronic 3D printing condition said that it was a decent printer for the price bracket.[^1] So I picked one up. It's proven to be helpful in many ways, and has enabled projects that would have previously involved road trips--I love visiting my girlfriend, but spending 4 hours driving every time I want to 3D print something is not how I want to spend my life.

As an example, the first major non-printer project I did successfully on this printer was a shield project for the lightsaber class I teach. I was able to design and print shield handle brackets on my own.[^2] Even being able to print prototypes and test fits is a big help.

However, after only a few projects, I am already feeling the limits of the stock firmware. With Orca Slicer, I seem to be having overextrusion problems, felt most strongly with supports sticking too aggressively. The standard firmware lacks features. And I would love to not do the SD card dance. (It's not _that_ big of a deal, but if I'm doing the rest of this anyway, might as well.)

So my design requirements are:

* Use Klipper, because might as well go for broke
* Try to use stock hardware and electronics--namely the standard screen
* Minimize loopbacks and weird dangling cables--I want the final product to be tidy and maybe look stock[^2.5]


[^1]: That modifier clause boy is doing some heavy lifting there. She might have paid twenty times what I did for her Bambu X1C, but boy howdy does it run sprints around my Ender in a plethora of ways.

[^2]: That girlfriend helped a lot with the wooden shield blanks, and she did design and print the Mk2 version of the handle. The work she did with the straps turned out to be completely useless, though.

[^2.5]: If I take off my glasses and squint


## Design

### Software

Ok, so we're going to be playing in the Klipper ecosystem. That means either OctoPrint or Moonraker & Friends.

The hardware will be a Raspberry Pi 4, mostly cause it's an easy and well-supported default, and I don't feel like going down the SBC rabbit hole.

There are [drivers](https://github.com/odwdinc/DWIN_T5UIC1_LCD/network) for the stock screen, but only for Moonraker. So let's go with that.

Moonraker is only an API, and has two major frontends: Mainsail and Fluidd. MainsailOS is maintained, unlike FluiddPI, so let's go with Mainsail.


### Compute

(A lot of credit goes to @agmlego and @mtfurlan for this hardware, but I will be putting my own spin on this.)

Ok, so let's start with a Raspberry Pi 4.

Let's give it a heatsink and fan. The [Geekworm 11mm heatsink](https://geekworm.com/products/p165-b)[^3] and the [Argon40 fan hat](https://argon40.com/products/argon-fan-hat) to start with. Except we're going to stack more boards on top of that fan, so let's use a [blower](https://www.amazon.com/dp/B08R9HB2XC) instead.

For a power supply, let's use a packaged 24v-5v DC-DC converter, like [this one](https://www.amazon.com/dp/B00J3MHRNO).

@mtfurlan was kind enough to give me one of her OctoPrint IO boards ([Hardware GitHub](https://github.com/mtfurlan/um2-octoprint-breakout), [Software Blogpost](https://technicallycompetent.com/octoprint-physical-buttons/)). But I want more IO than that (namely, connectors to the front screen and driver board). Thankfully, it's a trivial board, so I'll build my own based on an [Adafruit Perma Proto Bonnet Mini Kit](https://www.adafruit.com/product/3203)[^4].

@agmlego was also kind enough to send a Pi camera, case and ribbon, so I should use that, too.[^4.5]

[^3]: Do not use the included silpads, they are too thick and there are reports of people cracking their Pis. Use some PC thermal paste instead.

[^4]: You could also use a [Adafruit Perma-Proto HAT for Pi Mini Kit](https://www.adafruit.com/product/2310), it was just out of stock when I ordered everything.

[^4.5]: @agmlego did provide a bunch of the misc. hardware for this. All of it was because she bought extras for her own Ender 5 project.


### Electronics

So how does that compute integrate with the printer?

For data, there's a [hardware serial port](https://github.com/Harrypulvirenti/KlipperConfigS1/wiki/UART-Connection), so let's use that.[^5]

@agmlego was generous enough so supply an appropriate relay board for the Pi to control the main power, so I'll wire that up.

TODO: Power sense.

Part of @mtfurlan's design is two buttons and an indicator LED (integrated into one of the buttons), so I'll also provision for those.

I'm going to be using actual connectors and cables for everything--no loose jumper wires.


[^5]: There's also an [internal USB port](https://www.reddit.com/r/3Dprinting/comments/t5ohgq/ender3_s1_serialuart/), but I decided to skip the USB stack.


### Mechanics

I only need a few brackets--one for the Pi and one for the camera.

For the Pi, I settled on a custom variant of the [Display Mount Ender 3 S1 Pro with Raspberry PI 3 Case by 1h0m5s](https://www.printables.com/model/777751-display-mount-ender-3-s1-pro-with-raspberry-pi-3-c).

"Variant"--none of the available versions are compatible with the Pi 4 with two inches of hat on top. And none of them seem to have sources (not that sources would do me much with this much work). And they all put the ethernet port in a weird direction. So a more accurate description might be a custom screen bracket & Pi case, loosely inspired by 1h0m5s's work.

TODO: Camera arm


## Building it

### IO hat

TODO: Schematic, photos

### Raspberry Pi Stackup

TODO: Photos, link to agm's rim

### Bracket

TODO: Photos, link to printable

### Electronics

TODO: Photos

### Software

TODO


## Results

TODO: Did it work?
