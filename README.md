# vlche/nginx-waf-certbot
Docker alpine based container providing [nginx](https://www.nginx.com) with [modsecurity](https://www.modsecurity.org) and certbot for [Let's Encrypt](https://letsencrypt.org)'s SSL certificates.
Additionally preconfigured options are:

[lua](https://www.nginx.com/resources/wiki/modules/lua/) 

[brotli](https://github.com/google/brotli) 

[Optimized intermediate ssl settings. General-purpose servers with a variety of clients, recommended for almost all systems](https://ssl-config.mozilla.org/) 

Inspired by [Troy Kelly](https://hub.docker.com/r/really/nginx-modsecurity)

[![Docker Automated build](https://img.shields.io/docker/cloud/automated/vlche/nginx-waf-certbot.svg?style=for-the-badge)](https://hub.docker.com/r/vlche/nginx-waf-certbot/) 
[![Docker Build Status](https://img.shields.io/docker/cloud/build/vlche/nginx-waf-certbot.svg?style=for-the-badge)](https://hub.docker.com/r/vlche/nginx-waf-certbot/) 
[![GitHub issues](https://img.shields.io/github/issues/vlche/docker-nginx-waf.svg?style=for-the-badge)](https://github.com/vlche/docker-nginx-waf/issues) 
[![GitHub license](https://img.shields.io/github/license/vlche/docker-nginx-waf.svg?style=for-the-badge)](https://github.com/vlche/docker-nginx-waf/blob/master/LICENSE) 
[![Docker Pulls](https://img.shields.io/docker/pulls/vlche/nginx-waf-certbot.svg?style=for-the-badge)](https://hub.docker.com/r/vlche/nginx-waf-certbot/) 
[![MicroBadger Size](https://img.shields.io/docker/image-size/vlche/nginx-waf-certbot/latest.svg?style=for-the-badge)](https://hub.docker.com/r/vlche/nginx-waf-certbot/)

Launch nginx using the default config:
```
docker run --name nginx-waf \
  --restart=always \
  --net=host \
  -e TZ=Europe/Berlin \
  -v /data/nginx/conf.d:/etc/nginx/conf.d:rw \
  -v /data/letsencrypt:/etc/letsencrypt:rw \
  -v /data/www:/www:rw \
  -p 80:80 -p 443:443 -d \
  vlche/nginx-waf-certbot
```

ModSecurity
-----------
Pre-configured with rules from OWASP CRS on my default.
If you want to disable it for a particular location simply set it to off
```
server
{
  listen 80;
  listen [::]:80;
  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  server_name insecure.example.com;

  set $upstream "http://10.0.0.1:9000";

  # include letsencrypt endpoints to bypass proxy
  include /etc/nginx/snippets/letsencrypt.conf;
  # set proxy headers: X-Forwarded-Proto, Host, X-Forwarded-Host, X-Forwarded-For, X-Real-IP
  include /etc/nginx/snippets/proxy_headers.conf;
  # add some CSRF headers
  include /etc/nginx/snippets/policy_headers.conf;

  location /
  {
    proxy_pass $upstream;
    modsecurity off;
  }

  # disable SecRule # 949110 for /api/ route:
  location /api/
  {
    proxy_pass $upstream;
    modsecurity_rules "SecRuleRemoveById 949110";
  }

  ssl_certificate /etc/letsencrypt/live/insecure.example.com/fullchain.pem; # managed by Certbot
  ssl_certificate_key /etc/letsencrypt/live/insecure.example.com/privkey.pem; # managed by Certbot

  ssl_trusted_certificate /etc/letsencrypt/live/insecure.example.com/chain.pem; # managed by Certbot
  ssl_stapling on; # managed by Certbot
  ssl_stapling_verify on; # managed by Certbot

}
```

If you have multiple server blocks, it is recommended to load ModSecurity rules file in http context, and then customize SecRules per endpoints, to ruduce memory footprint.
Example of /etc/nginx/conf.d/00-local.conf:
```
# modsec is enabled for every server context.
# If you want to enable it on a per server basis, please disable it here!
modsecurity on;
modsecurity_rules_file /etc/nginx/modsec/main.conf;

# you should use reachable resolver for ssl stapling
# this one is generated from /etc/resolv.conf's first nameserver
include snippets/resolver.conf;
# this one is whatever you say
#resolver 8.8.8.8;

include snippets/brotli.conf;
```

Certbot
-------
Easily add SSL security to your nginx hosts with certbot.
`docker exec -it nginx-waf /bin/sh` will bring up a prompt at which time you can `certbot` to your hearts content.

_or_

`docker exec -it nginx-waf certbot --no-redirect --must-staple -d example.com`

It even auto-renew's for you every day!
