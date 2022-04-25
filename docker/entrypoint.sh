#!/bin/bash

redis-server --daemonize yes
systemctl start librephotos-worker.service && systemctl start librephotos-backend && systemctl start librephotos-image-similarity.service && echo
systemctl enable librephotos-backend
systemctl enable librephotos-worker.service
systemctl enable librephotos-image-similarity.service
systemctl start librephotos-frontend
systemctl enable librephotos-frontend
service postgresql start
bash ./postgres-entrypoint.sh
systemctl start postgresql.service
systemctl enable postgresql.service
bash ./backend-entrypoint.sh
systemctl restart nginx
# keep container running
while true; do sleep 1; done
