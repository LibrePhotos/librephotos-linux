#!/bin/bash
if [ -n "$SECRET_KEY" ]
then
    echo "Use env SECRET_KEY"
else 
    if [ -f /logs/secret.key ]
    then
        echo "Use existing secret.key"
        SECRET_KEY=`cat /logs/secret.key`
        export SECRET_KEY=$SECRET_KEY
    else
        echo "Create new secret.key"
        SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
        echo $SECRET_KEY > /logs/secret.key
        export SECRET_KEY=$SECRET_KEY
    fi
fi

python manage.py showmigrations 
python manage.py migrate 
python manage.py showmigrations
python manage.py clear_cache 
echo "Running production backend server..."
