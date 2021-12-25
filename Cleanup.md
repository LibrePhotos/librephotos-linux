# How to cleanup (Ubuntu)

## Almost all in one place  
This removes files from system, drps database. Installed from repositories or compiled software must remove manually.
``` bash
su - postgres << EOF
psql -c 'DROP DATABASE IF EXISTS librephotos;'
psql -c 'DROP USER IF EXISTS librephotos;'
exit
EOF
systemctl disable librephotos-backend
systemctl disable librephotos-worker.service
systemctl disable librephotos-image-similarity.service
systemctl disable librephotos-backend
rm -r /etc/systemd/system/librephotos-*
userdel -fr librephotos
rm -r $BASE_DATA/data_models/
rm -r $BASE_DATA/protected_media
rm -r /etc/librephotos/
rm -r /var/log/librephotos
unlink /usr/sbin/librephotos-cli
rm /etc/nginx/sites-enabled/librephotos
rm /etc/nginx/sites-available/librephotos
service nginx reload
```

# Some explanation what to clean up.

## Compiled software uninstallation  
Go to the source folder, and run  
```bash
make uninstall
```  

Or dirty way:
Delete all releated files in the `/usr/local/include`, also check in the `/usr/local/....` documentation files, etc.  

Sometimes Librephotos not starting after installation. If on the systems left some old compiled packages, will result version mismatch, and gunicorn (backend) will not start. Uninstall compiled (local) software and try again.

## Cleanup database by droping it and user  
``` bash
su - postgres << EOF
psql -c 'DROP DATABASE IF EXISTS librephotos;'
psql -c 'DROP USER IF EXISTS librephotos;'
exit
EOF
```

## Delete system user and remove HOME
Default home `/usr/lib/librephotos`. This action removes frontend, backend and all other files in the librephotos home.
```bash
userdel -fr librephotos
```  

## Disabling systemd services  
```bash
systemctl disable librephotos-backend
systemctl disable librephotos-worker.service
systemctl disable librephotos-image-similarity.service
systemctl disable librephotos-backend
```
And removing service files:
```bash
rm -r /etc/systemd/system/librephotos-*
```

## Cleanup folders  
### logs  
```bash
rm -r /var/log/librephotos
```
### thumbails, some software like places, clips-embeddings, etc). Photo not touching in the $BASE_DATA/data
```bash
rm -r $BASE_DATA/data_models/
rm -r $BASE_DATA/protected_media
rm -r /etc/librephotos/
```  

### unlinking    
```bash
unlink /usr/sbin/librephotos-cli
```
### nginx  
#### virtual host. Only if nginx were before librephotos installation  
```bash
rm /etc/nginx/sites-enabled/librephotos
rm /etc/nginx/sites-available/librephotos
service nginx reload
```
#### if nginx installed by the script  
```bash
systemctl stop nginx
apt remove --purge nginx
```
### Other software.  
If software are only for librephotos, can remove redis-server, postgresql. All other not recommend - maybe it is used to other purposes.
