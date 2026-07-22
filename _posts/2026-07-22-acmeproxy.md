---
layout: post-text
title: Acmeproxy for Fun and Villainy
tags: homelab, caddy
excerpt_separator: <!--more-->
date: 2026-07-22 12:00:02
---

I would like to use TLS on internal servers on a bunch of boxes without giving everything DNS admin credentials.

<!--more-->

Requirements:

* Every cert is automatically managed with ACME
* Certs must be publicly trusted--signed by a real CA
* Minimize credential permissions


## Why not Caddy's ACME server?

It seemingly doesn't do any kind of proxying or cert handoff or whatever. It handles the request and signs the certificates using a local root.


## Background

acmeproxy is an ad-hoc standard for proxying DNS-01 challenges. That is, you have:

* Your CA and ACME provider (such as Let's Encrypt)
* Your DNS host (we're using namecheap at home)
  * Hopefully one with a [caddy-dns plugin](https://github.com/caddy-dns)
* The proxying Caddy server
  * This holds the credentials to your DNS provider
* The proxied servers trying to get certs

Some implementations include:
* [github.com/mdbraber/acmeproxy](https://github.com/mdbraber/acmeproxy)
* [github.com/MadCamel/acmeproxy.pl](https://github.com/MadCamel/acmeproxy.pl)
* [caddy-dns](https://github.com/caddy-dns/acmeproxy)
* [go-acme's lego](https://go-acme.github.io/lego/dns/httpreq/index.html)
* [acme.sh](https://github.com/acmesh-official/acme.sh/wiki/dnsapi2#dns_acmeproxy)
* [github.com/liujed/dns01proxy](https://github.com/liujed/dns01proxy) and [caddy-dns01proxy](https://github.com/liujed/caddy-dns01proxy)

I'll be using Caddy as both servers. The proxying server can be doing other things, depending on your taste.


## The Proxy Server

```dockerfile
FROM caddy:2-builder AS builder

RUN xcaddy build \
    --with github.com/liujed/caddy-dns01proxy \
    --with github.com/caddy-dns/acmeproxy

FROM caddy:2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

Caddy needs 3 plugins:
* `github.com/liujed/caddy-dns01proxy` is the actual proxy
* The appropriate `caddy-dns` plugin for your DNS host (not shown above)
* `github.com/caddy-dns/acmeproxy` is the proxy client
  * Not strictly necessary on this server, but probably good to include

You can run this using a standard compose (eg, [Caddy's recommendation](https://caddyserver.com/docs/running#docker-compose) or my [Caddy as ingress](/2026/07/22/docker-ingress.html)).

The tricky bit becomes the Caddyfile:

```
{
    cert_issuer acme {
        disable_http_challenge
        disable_tlsalpn_challenge
    }
}

(acme-config) {
    resolvers 1.1.1.1 # because split horizon dns
    dns namecheap {
        api_key {env.NAMECHEAP_API_KEY}
        user {env.NAMECHEAP_API_USER}
        api_endpoint https://api.namecheap.com/xml.response
        client_ip {env.NAMECHEAP_CLIENT_IP}
    }
}

acme.qwertyuiop.home {
    tls {
        import acme-config
    }
    @endpoints {
        path /present /cleanup
    }
    handle @endpoints {
        dns01proxy {
            import acme-config
            user acme {
                # Neither of these are optional
                password ACMEPROXY_TOKEN
                allow_domains *.qwertyuiop.home
            }
        }
    }
    respond 404
}
```

Highlights:
* If you're using a private DNS server, you must set `resolvers` to one or more public DNS
  * In testing, we found Cloudflare's 1.1.1.1 to be more responsive than Google's 8.8.8.8
  * The direct NS server for your domain would also be a good choice
* `(acme-config)` is used in a few places, so it's worth breaking that out
* This example uses namecheap; rewrite `(acme-config)` for your own setup
* dns01proxy's `password` and `allow_domains` are not optional---configure them!

If all goes well, you should be able to start Caddy and see log messages about getting a cert for `acme.qwertyuiop.home`.


### Additional Sites

If you want your proxy server to also host applications (eg, it's the main reverse proxy of your homelab), there's two ways:

Option the first, copy the DNS credentials into the local sites:

```
office.qwertyuiop.home {
    tls {
        import acme-config
    }
    reverse_proxy host.docker.internal:8081
}
```

Option the second, run it as an acmeproxy client as below.


## The Proxy Clients

Additional Caddy servers can be running elsewhere. To connect them, you can use a Caddyfile like:
```
test.qwertyuiop.home {
    tls {
        resolvers 1.1.1.1  # Same as above
        dns acmeproxy https://acme.qwertyuiop.home {
            username acme
            password ACMEPROXY_TOKEN
        }
    }
    reverse_proxy testserver:3000
}
```

(You can use [snippets](https://caddyserver.com/docs/caddyfile/concepts#snippets) to avoid repeating this.)
