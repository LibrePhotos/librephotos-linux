# Compiled software uninstallation  
Go to the source folder, and run  
```bash
make uninstall
```  

Or dirty way:
Delete all releated files in the `/usr/local/include`, also check in the `/usr/local/....` documentation files, etc.  

# Cleanup database by droping it and user  
``` bash
su - postgres << EOF
psql -c 'DROP DATABASE IF EXISTS librephotos;'
psql -c 'DROP USER IF EXISTS librephotos;'
exit
EOF
```

# Delete system user and remove HOME
```bash
userdel -fr librephotos
```  

# Disabling systemd services  
```bash
systemctl disable librephotos-backend
systemctl disable librephotos-worker.service
systemctl disable librephotos-image-similarity.service
systemctl disable librephotos-backend
```

# Cleanup folders  
## logs  
```bash
rm -r /var/log/librephotos
```
## thumbails, some software like places, clips-embeddings, etc). Photo not touching in the $BASE_DATA/data
```bash
rm -r $BASE_DATA/data_models/
rm -r $BASE_DATA/protected_media
rm -r /etc/librephotos/```  

## systemd files
```bash
rm -r /etc/systemd/system/librephotos-*
```
## unlinking    
```bash
unlink /usr/sbin/librephotos-cli
```
## nginx  
### virtual host. Only if nginx were before librephotos installation  
```bash
rm /etc/nginx/sites-enabled/librephotos
rm /etc/nginx/sites-available/librephotos
service nginx reload
```
### if nginx installed by the script  
```bash
systemctl stpo nginx
apt remove --purge nginx
```
## Other software.  
If software are only for librephotos, can remove redis-server, postgresql. All other not recommend - maybe it is used to other purposes.
