#!/bin/bash
cd /usr/lib/librephotos/backend
if [ -n "$SECRET_KEY" ]
then
    echo "Use env SECRET_KEY"
else 
    if [ -f $BASE_LOGS/secret.key ]
    then
        echo "Use existing secret.key"
        SECRET_KEY=`cat $BASE_LOGS/secret.key`
        export SECRET_KEY=$SECRET_KEY
    else
        echo "Create new secret.key"
        SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
        echo $SECRET_KEY > $BASE_LOGS/secret.key
        export SECRET_KEY=$SECRET_KEY
    fi
fi

set -o allexport
source /etc/librephotos/librephotos-backend.env
set +o allexport

cd /usr/lib/librephotos/backend
python3 manage.py showmigrations 
python3 manage.py migrate 
python3 manage.py showmigrations
python3 manage.py clear_cache 
echo "Running production backend server..."
EOF
