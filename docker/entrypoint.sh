#!/bin/bash

if [[ -z "${FIXPERMISSIONS}" ]]; 
then
  echo "If you have file permission issues, use -e FIXPERMISSIONS=true"
else
  chmod -R 777 /var/lib/librephotos/photos/
fi

chown -R librephotos:librephotos /var/log/librephotos
chown -R librephotos:librephotos /var/lib/librephotos/data/protected_media/

redis-server --daemonize yes
systemctl restart librephotos-backend 
systemctl restart librephotos-worker.service
systemctl restart librephotos-image-similarity.service
systemctl restart librephotos-thumbnail.service
systemctl restart librephotos-frontend
systemctl restart nginx
export PATH=/lib/postgresql/13/bin:$PATH
postgres-entrypoint.sh postgres
# keep container running
while true; do sleep 1; done
