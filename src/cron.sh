#!/bin/sh
set -eu

if [ -z "${WAF_INSTANCE:-}" ];then
    WAF_INSTANCE='nginx-waf'
fi

# fix of certbot's deploy hook
if [ ! -d /etc/letsencrypt/renewal-hooks/deploy ]; then
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
else
    rm -rf /etc/letsencrypt/renewal-hooks/deploy/*
fi

if [ ! -d /etc/letsencrypt/html ]; then
    mkdir -p /etc/letsencrypt/html
fi

cat <<EOF >/etc/letsencrypt/renewal-hooks/deploy/nginx-reload
#!/bin/sh

id=\$(curl -s -XPOST -H "Content-Type: application/json" -d '{ "Cmd": [ "nginx", "-s", "reload" ] }' --unix-socket /run/docker.sock http://localhost/containers/${WAF_INSTANCE}/exec|sed 's/[\"\{\}]//g'|cut -d: -f2)
curl -s -XPOST -H "Content-Type: application/json" -d '{ "Detach": false, "Tty": false}' --unix-socket /run/docker.sock http://localhost/exec/\${id}/start
EOF
chmod a+x /etc/letsencrypt/renewal-hooks/deploy/nginx-reload

exec busybox crond -f -l 0 -L /dev/stdout
