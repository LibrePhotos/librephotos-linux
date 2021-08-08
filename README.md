# LibrePhotos installation script for Linux

## Compatibility
  NOT WORKING YET

## Pre-Installation

Install git:
~~~
sudo apt install git -y
~~~

## Installation

### Debian like distribution

Execute the following commands as root. This will create systemuser 'librephotos', creates directories, install necessary software, creates database and automaGically writes some variables to librephotos-backend.env file.
~~~
sudo su
cd /tmp/
git clone https://github.com/Seneliux/librephotos-linux.git
cd librephotos-linux
./install-librephotos_backend.sh
~~~

Edit '/etc/librephotos/librephotos-backend.env' to store configuration variables, such as:

 - redis information
In case you configured it with a password or are using a special path.

 - Mapbox API Key
MAPBOX_API_KEY=YOURAPIKEY

~~~
nano /etc/librephotos/librephotos-backend.env
~~~

Create or update database
~~~
/usr/lib/librephotos/bin/librephotos-upgrade
~~~

Create admin user as root with the following command
~~~
/usr/lib/librephotos/bin/librephotos-createadmin <user> <email> <pasword>
~~~

reboot or start services
~~~
systemctl start librephotos-image-similarity.service
systemctl start librephotos-worker.service
systemctl start librephotos-backend
systemctl start librephotos-frontend
~~~

## additional information

### librephotos-cli

As root you can use

~~~
librephotos-cli build_similarity_index
librephotos-cli clear_cache
~~~
