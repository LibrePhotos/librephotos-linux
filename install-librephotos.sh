#!/bin/bash

######################### HERE EDIT VARIABLES ################################################
# the location of photos. If changed here, also must change the path in the nginx virtual host.
# /etc/nginx
export PHOTOS=/var/lib/librephotos/photos
export BASE_DATA=/var/lib/librephotos/data

######## Below change ONLY if you know what are you doing. #####################
# Front-end’s IPs from which allowed to handle set secure headers. (comma separate).
# Ref: https://docs.gunicorn.org/en/stable/settings.html#forwarded-allow-ips
# Ref2: https://github.com/benoitc/gunicorn/issues/1857
# '*' to disable
export FORWARDED_ALLOW_IPS=

# PostgreSQL connection settings
DB_HOST=localhost
DB_PORT=5432
# DB_USER Must match DB_USER in resources/etc/librephotos/librephotos-backend.env
# and not be used by other installed software. This user will be removed and recreated.
DB_USER=docker

# If postgresql server is NOT local, after installation remove from these files
# /etc/systemd/system/librephotos-backend.service
# /etc/systemd/system/librephotos-worker.service
# these settings:
# postgresql.service
# Requires=postgresql.service
######################### END OF EDITABLE SECTION #########################################

set -exa
# PRE INSTALL
# if exist, removes old user
check_user=$(awk -F: -v user=librephotos '$1 == user {print $1}' /etc/passwd)
[[ $check_user ]] && userdel -rf librephotos
[[ -d /usr/lib/librephotos ]] && rm -rf /usr/lib/librephotos
id -g librephotos > /dev/null || groupadd -r librephotos
id -u librephotos > /dev/null || useradd --home-dir /usr/lib/librephotos --comment "librephotos user" -g librephotos -mr -s /usr/sbin/nologin librephotos

export BASE_LOGS=/var/log/librephotos

mkdir -p $BASE_LOGS
mkdir -p $PHOTOS
mkdir -p $BASE_DATA/data_models/{places365,im2txt,clip-embeddings}
mkdir -p $BASE_DATA/protected_media/{thumbnails_big,square_thumbnails,square_thumbnails_small,faces}
mkdir -p $BASE_DATA/nextcloud_media
chown -R librephotos:librephotos $BASE_LOGS
chown -R librephotos:librephotos $PHOTOS
chown -R librephotos:librephotos $BASE_DATA

# Add PPA to install older postgresql version
REQUIRED_PKG=(wget gnupg gnupg2 gnupg1 lsb-release)
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done
# Create the file repository configuration:
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
# Import the repository signing key:
wget --no-check-certificate --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
# Update the package lists:
apt-get update

# CREATING DATABASE
REQUIRED_PKG=(postgresql-13)
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done

if [[ -z "${DOCKERDEPLOY}" ]]; 
then
    systemctl start postgresql.service
    systemctl enable postgresql.service
    su - postgres << EOF
psql -c "DROP DATABASE IF EXISTS librephotos;"
psql -c "DROP USER IF EXISTS $DB_USER;"
psql -c "CREATE USER $DB_USER with encrypted password 'AaAa1234';"
psql -c "CREATE DATABASE librephotos WITH OWNER $DB_USER TEMPLATE = template0 ENCODING = 'UTF8';"
psql -c "GRANT ALL privileges ON DATABASE librephotos TO $DB_USER;"
exit
EOF
else
    echo "skipping db init"
fi


# LIBREPHOTOS : BACKEND

REQUIRED_PKG=( wget swig ffmpeg libimage-exiftool-perl libpq-dev  curl libopenblas-dev libmagic1 libboost-all-dev libxrender-dev \
liblapack-dev git bzip2 cmake build-essential libsm6 libglib2.0-0 libgl1-mesa-glx gfortran gunicorn \
libheif-dev libssl-dev rustc liblzma-dev python3 python3-pip imagemagick )
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done
# This part compiles libvips. More info https://libvips.github.io/libvips/install.html
REQUIRED_PKG=( build-essential pkg-config libglib2.0-dev libexpat1-dev libgsf-1-dev liborc-dev libexif-dev libtiff-dev \
 librsvg2-dev libpng-dev libwebp-dev )
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
 done

# Some packages differs in Ubuntu and Debian. Here script checks distro and installs correct packages
distro=$(lsb_release -i | awk '{print($3)}')
# here Ubuntu packages
[[ $distro == Ubuntu ]] && REQUIRED_PKG=( libjpeg-turbo8-dev )
# here Debian packages
[[ $distro == Debian ]] && REQUIRED_PKG=( libjpeg62-turbo-dev )
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
 done

# Compiling libvips from source. Installed libvips42 from repositories not working.
if ! which vips; then
wget https://github.com/libvips/libvips/releases/download/v8.12.1/vips-8.12.1.tar.gz
tar xf vips-8.12.1.tar.gz
cd vips-8.12.1
[ $(dpkg-query -W -f='${Status}' libmagick++-dev 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y libmagick++-dev
./configure --with-magickpackage=ImageMagick
make -j$(nproc --all)
make install
ldconfig
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib' >>  /usr/lib/librephotos/.bashrc
cd ..
else
echo "VIPS already found on the system"
echo "Sometimes older vips can cause problems."
read -t 5 -p "If librephotos-backend not starting, try to uninstall vips and recompile again"
fi

su - -s $(which bash) librephotos << EOF
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/places365.tar.gz | tar -zxC $BASE_DATA/data_models/
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/im2txt.tar.gz | tar -zxC $BASE_DATA/data_models/
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/clip-embeddings.tar.gz | tar -zxC $BASE_DATA/data_models/
mkdir -p ~/.cache/torch/hub/checkpoints/
curl -SL https://download.pytorch.org/models/resnet152-b121ed2d.pth -o ~/.cache/torch/hub/checkpoints/resnet152-b121ed2d.pth
pip3 install --no-cache-dir torch torchvision --extra-index-url https://download.pytorch.org/whl/cpu
pip3 install -v --install-option="--no" --install-option="DLIB_USE_CUDA" dlib
pip3 install pyvips
git clone https://github.com/LibrePhotos/librephotos.git backend
cd backend
pip3 install -r requirements.txt
EOF

# POST INSTALL

usermod -a librephotos
[ -d /usr/lib/librephotos/bin ] || mkdir -p /usr/lib/librephotos/bin
cp resources/bin/* /usr/lib/librephotos/bin/
ln -fs /usr/lib/librephotos/bin/librephotos-cli /usr/sbin/librephotos-cli
chown -R librephotos:librephotos  /usr/lib/librephotos/bin/
cp -r resources/etc/librephotos/ /etc/
cp resources/systemd/* /etc/systemd/system/


sed -i "s|DB_HOST=|DB_HOST=${DB_HOST}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|DB_PORT=|DB_PORT=${DB_PORT}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|DB_PASS=password|DB_PASS=${pass}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|FORWARDED_ALLOW_IPS=|FORWARDED_ALLOW_IPS=${FORWARDED_ALLOW_IPS}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|BASE_DATA=|BASE_DATA=${BASE_DATA}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|PHOTOS=|PHOTOS=${PHOTOS}|g" /etc/librephotos/librephotos-backend.env

if [ -z "${DOCKERDEPLOY}" ] && [ -e /tmp/database_pass ]; then
    rm /tmp/database_pass
else
  echo "skipping temp database pass removal"
fi

systemctl start librephotos-worker.service && \
systemctl start librephotos-backend && \
systemctl start librephotos-image-similarity.service && \
systemctl start librephotos-thumbnail.service && \
echo
systemctl enable librephotos-backend
systemctl enable librephotos-worker.service
systemctl enable librephotos-image-similarity.service
systemctl enable librephotos-thumbnail.service

# LIBREPHOTOS : FRONTEND
REQUIRED_PKG=( curl git xsel git )
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done

[ $(dpkg-query -W -f='${Status}' nodejs 2>/dev/null | grep -c "ok installed") -eq 0 ] && \
curl -sL https://deb.nodesource.com/setup_14.x | bash - && apt install nodejs -y --no-install-recommends
npm install -g yarn
export NODE_OPTIONS=--max-old-space-size=2048
su - -s $(which bash) librephotos << EOF
git clone https://github.com/LibrePhotos/librephotos-frontend.git frontend
cd frontend
npm install
npm run postinstall
npm run build
npm install serve
EOF

systemctl start librephotos-frontend
systemctl enable librephotos-frontend

# NGINX REVERSE PROXY

if [ $(dpkg-query -W -f='${Status}' nginx* 2>/dev/null | grep -c "ok installed") -eq 0 ];
  then
    apt install -y nginx
    cp resources/etc/nginx/nginx.conf /etc/nginx/nginx.conf
    systemctl restart nginx
  else
    cp resources/etc/nginx/librephotos /etc/nginx/sites-available/librephotos
    ln -s /etc/nginx/sites-available/librephotos /etc/nginx/sites-enabled/
fi
echo "If system has the nginx server before installing librephotos, edit virtual host /etc/nginx/librephotos and restart nginx."
echo "Optimal: check other settings in the file /etc/librephotos/librephotos-backend.env"
echo "After changing BASE_DATA, must edit file /etc/nginx/nginx.conf, or /etc/nginx/sites-available/librephotos and change accordingly"
echo "alias. There  4 lines"-

