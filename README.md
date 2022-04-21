# LibrePhotos installation script for Linux

Currently, these are in a early stage; some bugs may exist. If you find any, please log an issue

## Contribution

These are community maintained scripts to allow for a local install. If you have implemented an improvement, please consider opening up a pull request.

## Notes

Script is not adopted to remote postgresql server.  
If REDIS present on the system AND connection to it through socket, change socket permissions to 770. librephotos user will be added to redis group.

## Compatibility

Architecture:
amd64

- Ubuntu 20.04.x LTS (server)
- Ubuntu 21.04 (desktop)
- Debian

## Pre-Installation

Install git:

```
sudo apt install git -y
```

## Installation

### Debian like distribution

Execute the following commands as root. Edit the begining of the script, and execute. This will create systemuser 'librephotos', creates directories, installs necessary software, creates database and automaGically writes some variables to librephotos-backend.env file.

```
sudo su
cd
git clone https://github.com/LibrePhotos/librephotos-linux.git
cd librephotos-linux
nano install-librephotos.sh
```

```
./install-librephotos.sh
```

After changing the photos directory, must edit one of the `/etc/nginx/nginx.conf` or `/etc/nginx/sites-available/librephotos`. There are four places `alias /var/lib/librephotos.

No cheking Apache or any other web server exsistense on system. Please adopt the script. Easiest way to remove all lines, releated with nginx, and create virtual host in Apache.

```
nano /etc/librephotos/librephotos-backend.env
```

## Additional information

Installed systemd services:

```
librephotos-image-similarity.service
librephotos-worker.service
librephotos-backend
librephotos-frontend
```

### librephotos-cli

Update database (on the first time this is already done by the script)

```
/usr/lib/librephotos/bin/librephotos-upgrade
```

Create admin user as root with the following command

```
/usr/lib/librephotos/bin/librephotos-createadmin <user> <email> <pasword>
```

As root you can use

```
librephotos-cli build_similarity_index
librephotos-cli clear_cache
```

## Docker command

```
docker run -v photos:/var/lib/librephotos/photos/ -v thumbnails:/var/lib/librephotos/data/protected_media -v logs:/var/log/librephotos/ -v db:/var/lib/postgresql/data/ -p 3000:80 reallibrephotos/singleton
```

## TO DO

- [ ] remote / local user permissions to write to the photos folder (samba, webdav, nextcloud, nfs)
- [ ] android sync (client, synthing, webdav)
