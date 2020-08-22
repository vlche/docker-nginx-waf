#!/bin/sh
# vim:sw=4:ts=4:et

set -e

if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
    exec 3>&1
else
    exec 3>/dev/null
fi

if [ ! -f "/etc/ssl/dhparam.pem" ]; then
#  /usr/bin/openssl dhparam -out /etc/ssl/dhparam.pem 2048
  curl https://ssl-config.mozilla.org/ffdhe2048.txt > /etc/ssl/dhparam.pem
  RES=$?
  # curl returned error, generate dhparams ourselves
  if [ ${RES} -ne 0 ];then /usr/bin/openssl dhparam -out /etc/ssl/dhparam.pem 2048 ;fi
  unset ${RES}
  echo "Done"
fi

# fix of certbot's permissions
if [ -d /etc/letsencrypt/live ]; then
    chmod o+rx /etc/letsencrypt/archive
    chmod o+rx /etc/letsencrypt/live
    chown .nginx /etc/letsencrypt/live/*/privkey.pem
    chmod g+r /etc/letsencrypt/live/*/privkey.pem
fi

if [ ! -z "${TZ}" ]; then
    if [ -f /usr/share/zoneinfo/${TZ} ]; then
        if [ -f /etc/localtime ]; then rm -f /etc/localtime; fi
        ln -s /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone
    fi
fi

if [ -f "/etc/nginx/snippets/resolver.conf" ]; then
    NS=$(cat /etc/resolv.conf|grep nameserver|head -n 1|cut -d' ' -f 2)
    sed -i 's/127.0.0.11/'${NS}'/' /etc/nginx/snippets/resolver.conf
fi

#if [ -f "/usr/sbin/crond" ]; then
#  /usr/sbin/crond -b -S -l 2
#fi

if [ "$1" = "nginx" -o "$1" = "nginx-debug" ]; then
    if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
        echo >&3 "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"

        echo >&3 "$0: Looking for shell scripts in /docker-entrypoint.d/"
        find "/docker-entrypoint.d/" -follow -type f -print | sort -n | while read -r f; do
            case "$f" in
                *.sh)
                    if [ -x "$f" ]; then
                        echo >&3 "$0: Launching $f";
                        "$f"
                    else
                        # warn on shell scripts without exec bit
                        echo >&3 "$0: Ignoring $f, not executable";
                    fi
                    ;;
                *) echo >&3 "$0: Ignoring $f";;
            esac
        done

        echo >&3 "$0: Configuration complete; ready for start up"
    else
        echo >&3 "$0: No files found in /docker-entrypoint.d/, skipping configuration"
    fi
fi

exec "$@"
