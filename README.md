# vlche/nginx-waf
Docker alpine based container providing [nginx](https://www.nginx.com) with [modsecurity](https://www.modsecurity.org) and certbot for [Let's Encrypt](https://letsencrypt.org)'s SSL certificates.
You can use  as all-in-one service, or as SSL/Load-Balancer in frontend and WAF as a backend/backends.
Additionally preconfigured options are:

[SSL/TLS](https://ssl-config.mozilla.org/) 
Optimized intermediate ssl settings. General-purpose servers with a variety of clients, recommended for almost all systems by Mozilla.
Certificates are from Lets's encrypt, generated by certbot, auto renewed by separate container, hooks are preconfigured to reload nginx-waf container

[brotli](https://github.com/google/brotli) 
Default preconfigured options for Brotli are: dynamic compression, level 6

[Security Headers](https://securityheaders.com/) 
Preconfigured optimized http headers are included and enabled, but you should certainly know what you are doing!

[lua](https://www.nginx.com/resources/wiki/modules/lua/) 

Inspired by [Troy Kelly](https://hub.docker.com/r/really/nginx-modsecurity)

[![Docker Automated build](https://img.shields.io/docker/cloud/automated/vlche/nginx-waf.svg?style=for-the-badge)](https://hub.docker.com/r/vlche/nginx-waf/) 
[![Docker Build Status](https://img.shields.io/docker/cloud/build/vlche/nginx-waf.svg?style=for-the-badge)](https://hub.docker.com/r/vlche/nginx-waf/) 
[![GitHub issues](https://img.shields.io/github/issues/vlche/docker-nginx-waf.svg?style=for-the-badge)](https://github.com/vlche/docker-nginx-waf/issues) 
[![GitHub license](https://img.shields.io/github/license/vlche/docker-nginx-waf.svg?style=for-the-badge)](https://github.com/vlche/docker-nginx-waf/blob/master/LICENSE) 
[![Docker Pulls](https://img.shields.io/docker/pulls/vlche/nginx-waf.svg?style=for-the-badge)](https://hub.docker.com/r/vlche/nginx-waf/) 
[![MicroBadger Size](https://img.shields.io/docker/image-size/vlche/nginx-waf/latest.svg?style=for-the-badge)](https://hub.docker.com/r/vlche/nginx-waf/)

Launch nginx-waf using the default config:
```
docker run --name nginx-waf \
  --restart=always \
  --net=host \
  -e TZ=Europe/Berlin \
  -v /data/nginx/conf.d:/etc/nginx/conf.d:rw \
  -v /data/letsencrypt:/etc/letsencrypt:rw \
  -v /data/www:/www:rw \
  -p 80:80 -p 443:443 -d \
  vlche/nginx-waf
```
Launch certbot's cron updater as a separate service. Change WAF_INSTANCE variable to match your nginx-waf instance
```
docker run --name nginx-waf-cron \
  --restart=always \
  -e TZ=Europe/Berlin \
  -e WAF_INSTANCE=nginx-waf \
  -v /data/nginx/conf.d:/etc/nginx/conf.d:rw \
  -v /data/letsencrypt:/etc/letsencrypt:rw \
  -v /data/www:/www:rw \
  -v /run/docker.sock:/run/docker.sock \
  vlche/nginx-waf
  /cron.sh
```

ModSecurity
-----------
Pre-configured with rules from OWASP CRS on my default.
If you want to disable it for a particular location simply set it to off
```
upstream backend {
    server 127.0.0.1:9000;
}

server {
    listen       80;
    #listen       [::]80;
    server_name  insecure.example.com;
    #listen 443 ssl http2;
    #listen [::]:443 ssl http2;

    #ssl_certificate /etc/letsencrypt/live/insecure.example.com/fullchain.pem; # managed by Certbot
    #ssl_certificate_key /etc/letsencrypt/live/insecure.example.com/privkey.pem; # managed by Certbot
    #ssl_trusted_certificate /etc/letsencrypt/live/insecure.example.com/chain.pem; # managed by Certbot
    #ssl_stapling on; # managed by Certbot
    #ssl_stapling_verify on; # managed by Certbot

    #access_log  /var/log/nginx/host.access.log  main;

    # modsec has already been enabled globally in 01-local.conf
    #
    #modsecurity on;
    #modsecurity_rules_file /etc/nginx/modsec/main.conf;

    # include letsencrypt endpoints to bypass proxy and be able to autoupdate:
    include snippets/letsencrypt.conf;
    # add some CSRF headers:
    include snippets/policy_headers.conf;

    location / {
        root   /usr/share/nginx/html;
    }

    # serve static files with modsecurity disabled
    #
    #location /static/ {
    #    modsecurity off;
    #    root   /usr/share/nginx/html;
    #}

    # disable SecRule # 949110 for /api/ route:
    #
    #location /api/ {
    # set proxy headers: X-Forwarded-Proto, Host, X-Forwarded-Host, X-Forwarded-For, X-Real-IP for upstreams:
    #    include snippets/proxy_headers.conf;
    #    proxy_pass $backend;
    #    modsecurity_rules "SecRuleRemoveById 949110";
    #}

    # proxy requests to remote WebSockets backends for /ws/ route:
    #
    #location /ws/ {
    # set proxy headers: X-Forwarded-Proto, Host, X-Forwarded-Host, X-Forwarded-For, X-Real-IP for upstreams,
    # enable connection upgrade:
    #    include snippets/proxy_headers_ws.conf;
    #    proxy_pass $backend;
    #}

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    # set proxy headers: X-Forwarded-Proto, Host, X-Forwarded-Host, X-Forwarded-For, X-Real-IP for upstreams:
    #    include snippets/proxy_headers.conf;
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}

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
# increased for nextcloud like apps
client_max_body_size        512m;

# define indexes here to reduce per vhost complexity
index  index.html index.htm;

# map to proxify WebSockets
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
```

Certbot
-------
Easily add SSL security to your nginx hosts with certbot.
`docker exec -it nginx-waf /bin/sh` will bring up a prompt at which time you can `certbot` to your hearts content.

_or_

`docker exec -it nginx-waf certbot --no-redirect --must-staple -d example.com`

It even auto-renew's for you every day!
