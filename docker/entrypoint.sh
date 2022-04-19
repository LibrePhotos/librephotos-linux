#! /bin/bash

systemctl start librephotos-worker.service && systemctl start librephotos-backend && systemctl start librephotos-image-similarity.service && echo
systemctl enable librephotos-backend
systemctl enable librephotos-worker.service
systemctl enable librephotos-image-similarity.service
systemctl start librephotos-frontend
systemctl enable librephotos-frontend
pg_ctlcluster 13 main start
systemctl start postgresql.service
systemctl enable postgresql.service
/usr/lib/librephotos/bin/librephotos-upgrade
