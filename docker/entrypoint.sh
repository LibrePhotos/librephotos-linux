#!/bin/bash

redis-server --daemonize yes
systemctl restart librephotos-backend 
systemctl restart librephotos-worker.service
systemctl restart librephotos-image-similarity.service
systemctl restart librephotos-frontend
systemctl restart nginx
export PATH=/lib/postgresql/13/bin:$PATH
postgres-entrypoint.sh postgres
# keep container running
while true; do sleep 1; done
