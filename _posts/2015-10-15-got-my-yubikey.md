---
layout: post-text
title: Got my YubiKey!
categories: []
tags: yubioco, yubikey, security, u2f
---

So a little while ago, Yubico and GitHub had a [promotion](https://www.yubico.com/github-special-offer/) where you could get one of the [YubiKey U2F](https://www.yubico.com/products/yubikey-hardware/fido-u2f-security-key/) devices for $5.

I naturally jumped on this like the west michigander I am.

It's about 1.5" long and sits comfortable on my keyring. Good design, feels robust, and looks good.

They do seem to fail to mention that on Linux, you have to install a udev rule:

{% gist astronouth7303/31778987657c0e61820e yubico.rules %}

If you don't, you'll get really weird errors, depending on what you're using (and none of them will "permission denied"). So if you're attemtpting to use U2F on Linux and it doesn't seem to be working, check your udev rules.

After I fixed that, everything worked out of the box as advertised. I got it hooked up to Google, GitHub, and Dropbox without any issues. They also have a [PAM module](https://github.com/Yubico/pam-u2f) available (which is in the Debian repositories) for local authentication, and their are third-party modules for disk encryption.

Of course, I would heartily endorse buying a second key, hooking it up to everything, and then stashing it in a safe place (maybe next to those 2-factor recovery codes?). If you loose your primary key, you could be locked out of everything.

When I understand [FIDO U2F](https://fidoalliance.org/specifications/overview/) better, I may post about it. It has some unexpected features and semantics, so reading is required.
