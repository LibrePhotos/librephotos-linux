# LibrePhotos installation script for Linux

## requirement 
  - Debian 11 (python 3.9)
  - postgresql
  - redis

## Installation

### Debian like distribution

Execute following commande as root
~~~
cd /tmp/
git clone https://github.com/LibrePhotos/librephotos-linux.git
cd librephotos-linux
./install-librephotos.sh 
~~~

Other way can be use download archive
~~~
wget https://github.com/librephotos/librephotos-linux/archive/main.zip -O /tmp/main.zip
unzip -d /tmp/ /tmp/main.zip
cd /tmp/librephotos-linux-main/
./install-librephotos.sh
~~~

Edit /etc/librephotos/librephotos-backend
 - SECRET_KEY
 - Postgresql information
 - redis information
~~~
nano /etc/librephotos/librephotos-backend
~~~

Create or update database
~~~
/usr/lib/librephotos/bin/librephotos-upgrade
~~~

Create admin user as root with the following commande
~~~
/usr/lib/librephotos/bin/librephotos-createadmin <user> <email> [<paswword>]
~~~

reboot or start services
~~~
systemctl start librephotos-image-similarity.service
systemctl start librephotos-worker.service
systemctl start librephotos-backend
systemctl start librephotos-frontend
~~~
### Other distribution

not working yet

## additional information

### for local postgresql and redis

Install postgresql and redis

~~~
apt install postgresql redis
~~~

### librephotos-cli

As root you can use 

~~~
librephotos-cli build_similarity_index
librephotos-cli clear_cache
~~~

### Postgresql creation database script

Open sql console
~~~
su - postgres -c /usr/bin/psql
~~~

Execute the bellow script after change values like password and user

~~~
CREATE USER librephotos WITH PASSWORD 'password';
CREATE DATABASE "librephotos" WITH OWNER "librephotos";
GRANT ALL privileges ON DATABASE librephotos TO librephotos;
quit
~~~

### Samba mount point sample

Install cifs-utils :

~~~
apt install cifs-utils
~~~

On /etc/fstab add the following line :

~~~
//data.lan.lgy.fr/ftcl/photos/ /var/lib/librephotos/data/photos cifs uid=librephotos,gid=librephotos,credentials=/etc/samba/smbcredentials,iocharset=utf8,file_mode=0777,dir_mode=0777,sec=ntlmssp,noacl 0 0
~~~

create file /etc/samba/smbcredentials with bellow connexion informations

~~~
username=thomas
password=mypassword
domain=my.domain.com
~~~
