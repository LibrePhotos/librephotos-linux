#!/bin/bash

redis-server --daemonize yes
systemctl restart librephotos-backend 
systemctl restart librephotos-image-similarity.service
systemctl restart librephotos-frontend
export PATH=/lib/postgresql/13/bin:$PATH
postgres-entrypoint.sh postgres
systemctl start postgresql.service
systemctl enable postgresql.service
systemctl restart nginx
# keep container running
while true; do sleep 1; done
