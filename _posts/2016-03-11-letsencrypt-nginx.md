---
layout: post-text
title: Let's Encrypt Nginx
tags: web, ssl, letsencrypt, nginx
---

I have seen the light! Let's Encrypt is well poised to become the SSL key manager for those of us who don't want to think about TLS. It's easy to setup and configure, and generally just does the right thing.

I set up a private [GOGS](https://gogs.io/) server, and decided to pull the stops on Doing Things Right. For me, that meant HTTPS, HTTP/2, and good TLS security. I have not set up [HSTS](https://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security) or [HPKP](https://en.wikipedia.org/wiki/HTTP_Public_Key_Pinning) yet, because I need more confidence in my setup before I do so. Rest assured, these are very easy to set up. (I won't be using [CSP](https://en.wikipedia.org/wiki/Content_Security_Policy) because I believe that should be decided on by the application, not the frontend server.)

Note: I did this on a FreeBSD system, but nothing in here is FreeBSD-specific.

**EDIT**: `letsencrypt` is now [Certbot](https://certbot.eff.org/). But this change hasn't migrated to FreeBSD yet, so this guide hasn't been updated.

Additional Note: You do have to do these in order.

You can follow along with my [gist](https://gist.github.com/astronouth7303/a11ec7009278ad65b53e).

Step 0: Installation
====================

This is system specific. Grab your package manager and install letsencrypt and nginx. If necessary, configure nginx to start at boot.

Step 1: Configure Nginx for Verification
========================================

Let's Encrypt only verifies the server name on the certificate is valid; they don't verify organizational or personal identities. That is, a certificate from Let's Encrypt asserts that you're talking to `qwertyuiop.ninja`, but it does not assert that it is operated by Astro Software, Inc.

To that end, Let's Encrypt performs automatic verification by looking for a specific file hosted by your server. So lets configure Nginx to serve it.

The way I do it is like this. First, in nginx.conf, I add this include:
{% highlight nginx %}
http {
    # ...
    server {
        listen       80;
        listen       [::]:80;

        include letsencrypt;
    }
    # ...
}
{% endhighlight %}

(This _must_ be served over plain HTTP.)

The contents of `letsencrypt` are simple:
{% highlight nginx %}
location '/.well-known/acme-challenge' {
    default_type "text/plain";
    root /tmp/letsencrypt;
}
{% endhighlight %}

The path `/tmp/letsencrypt` is unimportant. The file itself does not have to be secure, since any Lets Encrypt server will happily give it to anyone. You'll just need the path for Step 2.

Step 2: Get Your Key
====================

Now you need to ask Let's Encrypt to verify your host and issue you your first certificate.

All you need to do is run:
{% highlight shell %}
$ letsencrypt certonly --webroot -w /tmp/letsencrypt -d qwertyuiop.ninja
{% endhighlight %}

Step 3: Configure Nginx for SSL
===============================

Hop back to `nginx.conf` and set it up for SSL:

{% highlight nginx %}
http {
    # ...

    server {
        listen       443 ssl http2;
        listen       [::]:443 ssl http2;
        server_name  qwertyuiop.ninja;

        ssl_certificate      /usr/local/etc/letsencrypt/live/qwertyuiop.ninja/fullchain.pem;
        ssl_certificate_key  /usr/local/etc/letsencrypt/live/qwertyuiop.ninja/privkey.pem;
        
        include tls;

        location / {
                proxy_pass http://172.28.9.3:3000;
        }
    }
}
{% endhighlight %}

So, three things here.

1. The path `/usr/local/etc/letsencrypt/live` is specific to FreeBSD. I'm guessing on Linux you will want `/etc/letsencrypt/live`, but you should verify for yourself.

2. The contents of `tls` are to boost the security of the SSL connection against various attacks. I'll get to its contents in a moment.

3. The `location /` block is application-specific. In this case, it's just passing the request back to GOGS.

So what's so mysterious about the `tls` file? Honestly, I don't know the details. I just listen to the experts.

{% highlight nginx %}
# From https://cipherli.st/
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
ssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off; # Requires nginx >= 1.5.9
ssl_stapling on; # Requires nginx >= 1.3.7
ssl_stapling_verify on; # Requires nginx => 1.3.7

#resolver $DNS-IP-1 $DNS-IP-2 valid=300s;
#resolver_timeout 5s;

#add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
#add_header X-Frame-Options DENY;
#add_header X-Content-Type-Options nosniff;

# Extra diffie-helmen stuff
ssl_dhparam /usr/local/etc/nginx/dhparams.pem;
{% endhighlight %}

The first block is something I just copy-and-pasted. It disables insecure protocols, removes some insecure TLS option, and turns on [OCSP stapling](https://en.wikipedia.org/wiki/OCSP_stapling).

I literally have no idea why cipherli.st included the second block or what it does.

The third block configures HSTS. This tells browsers to silently switch all HTTP requests to your server to HTTPS. Don't turn this on until you are sure SSL works and you have it configured correctly. Doing this wrong can make your site inaccessible in your browser.

The last bit has to do with another attack. Diffie-Helmen is an algorithm for key exchange, and part of it is based on prime numbers. Except that many servers use the same prime numbers, leaving their connections vulnerable to anyone who has cracked their primes. You can fix this by using your own.

First, use the `openssl` program to generate new primes:
{% highlight shell %}
$ openssl dhparam -out /usr/local/etc/nginx/dhparams.pem 2048
{% endhighlight %}

This will take a few minutes, so this is a good time to stretch your legs and get a fresh coffee.

And then plug in this generated file into your nginx configuration, as I did above. And now your SSL security just got bumped for a coffee's break of work.

Step 4: Test
============

Reload nginx and verify HTTPS is working. Congrats! Your website is a good chunk more secure.

Step 5: Redirect HTTP to HTTPS
==============================

So now that you know HTTPS is working, time to start finishing up.

Open up `nginx.conf` and configure HTTP to redirect to HTTPS:
{% highlight nginx %}
http {
    # ...

    server {
        listen       80;
        listen       [::]:80;

        include letsencrypt;
        location / {
                return 301 https://$host$request_uri;
        }
    }

    # ...
}
{% endhighlight %}

If want, you can turn HSTS on at this time. However, I'm not certain how HPKP interacts with Let's Encrypt's short certificate lifespan, so you may want to hold off on that for the moment.

Step 6: Test Again and Verify SSL Strength
==========================================

Test again in the browser. Make sure HTTP is redirecting to HTTPS. If you're using HSTS, verify the headers and check that browsers are respecting it.

You may also want to take a moment and test with the [Qualys SSL Server Test](https://www.ssllabs.com/ssltest/index.html). This will give you a grade representing how secure your SSL connection is and point out areas that you're weak. You should be getting an 'A' grade.

Step 7: Automatic Refresh
=========================

One last thing you want to do: Set up cron jobs to refresh everything you generated above. Unless you want to be renewing certificates every two and a half months. Thankfully Let's Encrypt pretty much handles this for you. (There's a reason I called it the "SSL key manager for those of us who don't want to think about TLS".)

The Let's Encrypt program does the right thing in that it checks the state of your certificates and only renews if it has two weeks or less to live. So we can just ask it to check.

{% highlight cron %}
0       0       *       *       1       mkdir -p /tmp/letsencrypt && letsencrypt renew && service nginx reload
0       0       *       *       4       openssl dhparam -out /usr/local/etc/nginx/dhparams.pem 2048 && service nginx reload
{% endhighlight %}

**EDIT**: The Lets Encrypt (now called certbot) will _not_ prerenew your certificates. Once a week is not sufficient. I'm currently having it check daily.

The other job just refreshes the Diffie-Helmen parameters we made in step 3. I haven't seen any recommendations to do this, but I figure it can't hurt.

(I'm not certain reloading Nginx causes it to reread SSL keys and such, or if it does it automatically. I guess I'll find out in two and a half months.)

I have my jobs running once a week on different days. This is pretty much a personal preference.

And that's it! Again, my complete files are on [gists](https://gist.github.com/astronouth7303/a11ec7009278ad65b53e).