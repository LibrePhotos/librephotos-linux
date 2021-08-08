#!/usr/bin/env bash
set -ea

if [ $(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed") -eq 0 ];
  then
    apt install -y nginx
    cp ressources/etc/nginx/nginx.conf /etc/nginx/nginx.conf
    systemctl restart nginx
  else
    cp ressources/etc/nginx/librephotos /etc/nginx/sites-available/foto
    ln -s /etc/nginx/sites-available/foto /etc/nginx/sites-enabled/
    echo Must edit /etc/nginx/sites-available and restart nginx
fi
