# LibrePhotos installation script for Linux

## Compatibility
- Ubuntu 20.04.2 LTS

## Pre-Installation

Install git:
~~~
sudo apt install git -y
~~~
## ISSUES
Can not login if the first letter of the ADMIN_USERNAME is capital. Do not use capital letters in user names.

## Installation

### Debian like distribution

Execute the following commands as root. This will create systemuser 'librephotos', creates directories, installs necessary software, creates database and automaGically writes some variables to librephotos-backend.env file.
~~~
sudo su
cd /tmp/
git clone https://github.com/Seneliux/librephotos-linux.git
cd librephotos-linux
nano install-librephotos.sh
./install-librephotos.sh
~~~
Admin password will store in /tmp/ADMIN_PASS.
After changing the photos directory, must edit one of the `/etc/nginx/nginx.conf` or `/etc/nginx/sites-available/librephotos`. There are three places `alias /var/lib/librephotos`.

Edit `/etc/librephotos/librephotos-backend.env` to store configuration variables, such as:

 - redis information
In case you configured it with a password or are using a special path.

~~~
nano /etc/librephotos/librephotos-backend.env
~~~

## Additional information

Installed services:
~~~
librephotos-image-similarity.service
librephotos-worker.service
librephotos-backend
librephotos-frontend
~~~

### librephotos-cli

Update database (firs time this already done by script)
~~~
/usr/lib/librephotos/bin/librephotos-upgrade
~~~
Create admin user as root with the following command (first time this already done by script).
~~~
/usr/lib/librephotos/bin/librephotos-createadmin <user> <email> <pasword>
~~~
As root you can use
~~~
librephotos-cli build_similarity_index
librephotos-cli clear_cache
~~~
