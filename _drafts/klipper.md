---
layout: post-text
title: Ender 3 S1 and Klipper
---

Some time last year, MicroCenter had a sale on the Ender 3 S1. My girlfriend with a chronic 3D printing condition said that it was a decent printer for the price bracket.[^1] So I picked one up. It's proven to be helpful in many ways, and has enabled projects that would have previously involved road trips--I love visiting my girlfriend, but spending 4 hours driving every time I want to 3D print something is not how I want to spend my life.

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

Let's give it a heatsink and fan. The [Geekworm 11mm heatsink](https://geekworm.com/products/p165-b)[^3] and a [blower](https://www.amazon.com/dp/B08R9HB2XC) to direct air out the side.

For a power supply, let's use a packaged 24v-5v DC-DC converter, like [this one](https://www.amazon.com/dp/B00J3MHRNO).

@mtfurlan was kind enough to give me one of her OctoPrint IO boards ([Hardware GitHub](https://github.com/mtfurlan/um2-octoprint-breakout), [Software Blogpost](https://technicallycompetent.com/octoprint-physical-buttons/)). But I want more IO than that (namely, connectors to the front screen and driver board).

[^3]: Do not use the included silpads, they are too thick and there are reports of people cracking their Pis. Use some PC thermal paste instead.


### Electronics

So how does that compute integrate with the printer?

For data, there's a [hardware serial port](https://github.com/Harrypulvirenti/KlipperConfigS1/wiki/UART-Connection), so let's use that.[^5]

TODO: Two UARTs, [pinouts](https://pinout.xyz/pinout/uart), needs overlay

@agmlego was generous enough so supply an appropriate relay board for the Pi to control the main power, so I'll wire that up.

Part of @mtfurlan's design is two buttons and an indicator LED (integrated into one of the buttons), so I'll also provision for some of that.

I'm going to be using actual connectors and cables for everything--no loose jumper wires.

Some of the sources I'm using for pin assignments:

* https://technicallycompetent.com/octoprint-physical-buttons/
* https://github.com/Harrypulvirenti/KlipperConfigS1/wiki/UART-Connection
* https://github.com/RobRobM/DWIN_T5UIC1_LCD_E3S1/blob/main/README.md#wire-the-display

Ribbon pinout (printer side):

![printer ribbon pinout](https://github.com/RobRobM/DWIN_T5UIC1_LCD_E3S1/raw/main/images/Ender3S1_LCD_Board.JPG?raw=true)

[^5]: There's also an [internal USB port](https://www.reddit.com/r/3Dprinting/comments/t5ohgq/ender3_s1_serialuart/), but I decided to skip the USB stack.


### Mechanics

I only need a bracket for the Raspberry Pi. I settled on a custom variant of the [Raspberry Pi case (model B+/2/3) with Ender 3 S1 mounting bracket by p1mrx](https://www.printables.com/model/514923-raspberry-pi-case-model-b23-with-ender-3-s1-mounti).


## Building it

### Bracket

"Variant"--the original bracket by p1mrx was for the Pi3, granted with hat space. While there were actual source files available, it looks like the actual Pi3 holding bit was a mesh imported from another project--bad for updating it to Pi4. So I ended up [drawing my own from scratch](https://www.printables.com/model/1090733-raspberry-pi-4-case-for-ender-3-s1-beta).


### IO hat

At first I thought the IO hat was going to be a trivial design I could just wire onto some Adafruit Perma Proto, but when I got to stacks four wires high, I decided maybe I (@agmlego) should [make my own](https://github.com/agmlego/um2-octoprint-breakout).

Pinout:

* GPIO0/1: Hat ID EEPROM
* GPIO3: Pi power button
* GPIO4/5: UART to display
* GPIO10/11: I2C for additional sensors
* GPIO12: Display knob press
* GPIO13: Beeper
* GPIO14/15 (TXD/RXD): UART to printer
* GPIO17: Blue LED
* GPIO18: Pi blower PWM
* GPIO19/26: Display knob encoder[^10]
* GPIO22: Printer power sense
* GPIO23: Printer power relay
* GPIO24: Green LED
* GPIO27: Red LED

TODO: Schematic, photos

TODO: Device tree aside

[^10]: These are pins 35 & 37, which makes board routing easier


### Raspberry Pi Stackup

(The specific dimensions are vestigial from when the design included the Argon40 fan hat. Which proved to be a weird implementation and made pin assignments markedly harder.)

TODO: Photos, link to agm's rim

### Electronics

TODO: Photos

### Software

https://docs-os.mainsail.xyz/getting-started

https://github.com/Klipper3d/klipper/blob/master/config/printer-creality-ender3-s1-2021.cfg

STM32F401

### Slicer

Orca Slicer

Put in printer hostname

Switch gcode from marlin to klipper

## Results

TODO: Did it work?
