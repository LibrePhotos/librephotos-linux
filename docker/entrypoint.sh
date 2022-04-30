#!/bin/bash

redis-server --daemonize yes
systemctl start librephotos-backend 
systemctl start librephotos-image-similarity.service
systemctl enable librephotos-backend
systemctl enable librephotos-image-similarity.service
systemctl start librephotos-frontend
systemctl enable librephotos-frontend
export PATH=/lib/postgresql/13/bin:$PATH
service postgresql start
postgres-entrypoint.sh postgres
systemctl start postgresql.service
systemctl enable postgresql.service
systemctl restart nginx
# keep container running
while true; do sleep 1; done
