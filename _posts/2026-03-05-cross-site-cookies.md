---
layout: post-text
title: Cross Site Cookies
tags: 
excerpt_separator: <!--more-->
---

Cookies aren't allowed between hosts, unless they're related. Unfortunately, that comes with a pile of caveats, some of which make local development hard.


## Cookie Security

Ok, so HTTP has [cookies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies), since before most of us touched a web browser. One of the features of cookies is that you can set the domain tree they apply to.

BUT.

* You can only set a single root domain, but it does apply to all subdomains
* That scope must include the current site (ie, you can't set a cookie on some random other site)
* It cannot be a public prefix (eg, you can't set a cookie on `com` or `io` and have it apply to half the internet)


## My Task

As a background: I run [Teahouse Hosting](https://teahouse.cafe/) (you should [pay me to host your site](https://counter.teahouse.cafe/r/qwertyuiop)).

I want to implement a signup button on the main site. (Which is static.) And I would like that button to change based on the user's current auth status in the admin panel. (Which is a separate page. Because the main site is static. So I have to use javascript. Because static.)

I did try this with [`fetch()`](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API) and [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS), but it turns out if you want to [make cross-site requests with cookies](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#including_credentials), you have to opt-in on both sides and open a train-sized hole in your security.

So I'm using cross-site cookies instead.

Doing this on real domains would be fairly easy, but I don't want to develop in production, and not every dev box has a public domain routed to it. And I want to stay in the [secure context](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts) carveout for localhost.

The development environment, btw, is two local servers:

* A static site auto-builder & server for the main site
* An ASGI server for the admin panel


## The Problems

So it turns out btowsers have complicated rules about if two domains are related. And I encounted some other security features that hindered me.

* `localhost:42` and `localhost:69` are completely different, unrelated sites
* `localhost` counts as a public prefix, so only sites on `localhost` can set cookies on `localhost`
* Firefox will ignore `/etc/hosts` for `localhost` and all its subdomains, instead resolving everything to `127.0.0.1`

And of course, none of this is documented (or, it's burried in other documents I was too tired to search for).

So what did I try to discover these rules?

* Just run them on `localhost:8000` and `localhost:8080`
* Run them on `127.0.1.1:8000` and `127.0.2.1:8000` and use `/etc/hosts` to give them names
* Use the solution below and use the names `alpha.localhost` and `bravo.localhost`

None of that works.


## The Solution

Ok, so I apparently need to have my applications accessible on `teahouse.localhost` and `something.teahouse.localhost` for it to be a representative (and working) test of the cookie situation.


### The Application

The admin panel sets some non-tracking status cookies on login with their domains set to the apex (`teahouse.localhost` or `teahouse.cafe`, depending on the environment).


### The Routing

I installed Caddy on my system and used this config:

```
http://localhost, http://*.localhost {
  bind 127.0.0.1
  reverse_proxy :8000
}

http://alpha.localhost, http://alpha.*.localhost {
  bind 127.0.0.1
  reverse_proxy :8001
}

http://bravo.localhost, http://bravo.*.localhost {
  bind 127.0.0.1
  reverse_proxy :8002
}

http://charlie.localhost, http://charlie.*.localhost {
  bind 127.0.0.1
  reverse_proxy :8003
}

http://delta.localhost, http://delta.*.localhost {
  bind 127.0.0.1
  reverse_proxy :8004
}

http://echo.localhost, http://echo.*.localhost {
  bind 127.0.0.1
  reverse_proxy :8005
}
```

So now port 80 will be proxied to a bunch of stuff I can run locally, and I can use the domains for a lot of things. In this case, I'll put the site on `teahouse.localhost` and `alpha.teahouse.localhost` (run the servers on ports 8000 and 8001.)


## The Result

After this wild goose chase and a more than a few minutes banging my head on my desk, this works beautifully. I'm able to easily develop the bit of JavaScript I need. I'm able to log in over here and see the button change over there. It's great.

I just need a nap.
