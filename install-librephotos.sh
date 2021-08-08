#!/usr/bin/env bash

######################### HERE EDIT VARIABLES #############################
# the location of photos. If changed here, also must change in nginx
export BASE_DATA=/var/lib/librephotos
export ADMIN_USERNAME=
export ADMIN_EMAIL=
# Not mandatory:
export MAPBOX_API_KEY=
# If your hardware without AVX and SSE instructions, seach in this file
# 'dlib' and read instructions :) In most cases this for the old hardware
######################### END OF EDITABLE SECTION ##########################

set -ea
# PRE INSTALL
id -g librephotos > /dev/null || groupadd -r librephotos
id -u librephotos > /dev/null || useradd --home-dir /usr/lib/librephotos --comment "librephotos user" -g librephotos -mr -s /usr/sbin/nologin librephotos

export BASE_LOGS=/var/log/librephotos

mkdir -p $BASE_LOGS
mkdir -p $BASE_DATA/data_models/{places365,im2txt}
mkdir -p $BASE_DATA/protected_media/{thumbnails_big,square_thumbnails,square_thumbnails_small,faces}
mkdir -p $BASE_DATA/data/nextcloud_media
chown -R librephotos:librephotos $BASE_LOGS
chown -R librephotos:librephotos $BASE_DATA

# LIBREPHOTOS : BACKEND

REQUIRED_PKG=( swig ffmpeg libimage-exiftool-perl libpq-dev postgresql curl libopenblas-dev libmagic1 libboost-all-dev libxrender-dev \
liblapack-dev git bzip2 cmake build-essential libsm6 libglib2.0-0 libgl1-mesa-glx gfortran gunicorn \
libheif-dev libssl-dev rustc liblzma-dev python3 python3-pip imagemagick redis )
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done

# This part compiles libvips. More info https://libvips.github.io/libvips/install.html
REQUIRED_PKG=( build-essential pkg-config libglib2.0-dev libexpat1-dev libgsf-1-dev liborc-dev libexif-dev libtiff-dev \
libjpeg-turbo8-dev librsvg2-dev libpng-dev libwebp-dev)
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done
wget https://github.com/libvips/libvips/releases/download/v8.11.2/vips-8.11.2.tar.gz
tar xf vips-8.11.2.tar.gz
cd vips-8.11.2
./configure
make
make install
ldconfig
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib' >>  /usr/lib/librephotos/.bashrc
cd ..

su - -s $(which bash) librephotos << EOF
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/places365.tar.gz | tar -zxC $BASE_DATA/data_models/
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/im2txt.tar.gz | tar -zxC $BASE_DATA/data_models/
mkdir -p ~/.cache/torch/hub/checkpoints/
curl -SL https://download.pytorch.org/models/resnet152-b121ed2d.pth -o ~/.cache/torch/hub/checkpoints/resnet152-b121ed2d.pth

pip3 install torch==1.7.1+cpu torchvision==0.8.2+cpu -f https://download.pytorch.org/whl/torch_stable.html
###########################################################################################################
# Here seting up AVX and SSE support. 
Comment out first line 'pip3 install...' and uncoment second. Must leave only one.
##########################################################################################################
pip3 install -v --install-option="--no" --install-option="DLIB_USE_CUDA" dlib
#pip3 install -v --install-option="--no" --install-option="DLIB_USE_CUDA" --install-option="--no" --install-option="USE_AVX_INSTRUCTIONS" --install-option="--no" --install-option="USE_SSE4_INSTRUCTIONS" dlib

git clone https://github.com/Seneliux/librephotos.git backend
cd backend
pip3 install -r requirements.txt
python3 -m spacy download en_core_web_sm
EOF

# CREATING DATABASE
su - postgres << EOF
psql -c 'CREATE USER librephotos;'
psql -c 'CREATE DATABASE "librephotos" WITH OWNER "librephotos" TEMPLATE = template0 ENCODING = "UTF8";'
psql -c 'GRANT ALL privileges ON DATABASE librephotos TO librephotos;'
exit
EOF
echo 'su - postgres -c "psql -U postgres -d postgres -c \"alter user librephotos with password tmp_password;\""' > /tmp/database_pass
pass=$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12};)
sed -i "s|tmp_password|'${pass}'|g" /tmp/database_pass
chmod +x /tmp/database_pass
/tmp/database_pass

# POST INSTALL

[ -d /usr/lib/librephotos/bin ] || mkdir -p /usr/lib/librephotos/bin
cp ressources/bin/* /usr/lib/librephotos/bin/
ln -fs /usr/lib/librephotos/bin/librephotos-cli /usr/sbin/librephotos-cli
chown -R librephotos:librephotos  /usr/lib/librephotos/bin/
cp -r ressources/etc/librephotos/ /etc/
cp ressources/systemd/* /etc/systemd/system/
sed -i "s|DB_PASS=password|DB_PASS=${pass}|g" /etc/librephotos/librephotos-backend.env
secret_key=$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-16};)
sed -i "s|SECRET_KEY=SecretKeyToBeDefined|SECRET_KEY=${secret_key}|g" /etc/librephotos/librephotos-backend.env
sed "s|BASE_DATA=|BASE_DATA=${BASE_DATA}|g" /etc/librephotos/librephotos-backend.env
sed "s|MAPBOX_API_KEY=|MAPBOX_API_KEY=${MAPBOX_API_KEY}|g" /etc/librephotos/librephotos-backend.env
rm /tmp/database_pass

systemctl enable librephotos-backend
systemctl enable librephotos-worker.service
systemctl enable librephotos-image-similarity.service

/usr/lib/librephotos/bin/librephotos-upgrade

systemctl start librephotos-backend
systemctl start librephotos-worker.service
systemctl start librephotos-image-similarity.service

# LIBREPHOTOS : FRONTEND
REQUIRED_PKG=( curl git xsel git )
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done

[ $(dpkg-query -W -f='${Status}' nodejs 2>/dev/null | grep -c "ok installed") -eq 0 ] && \
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash - && apt install nodejs -y --no-install-recommends
npm install -g yarn

su - -s $(which bash) librephotos << EOF
git clone https://github.com/Seneliux/librephotos-frontend.git frontend
cd frontend
npm install
npm run build
npm install serve
EOF

systemctl enable librephotos-frontend
ADMIN_PASS=$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12};)
/usr/lib/librephotos/bin/librephotos-createadmin ${ADMIN_USERNAME} ${ADMIN_EMAIL} ${ADMIN_PASS}
echo ${ADMIN_PASS} > /tmp/ADMIN_PASS

# NGINX REVERSE PROXY

if [ $(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed") -eq 0 ];
  then
    apt install -y nginx
    cp ressources/etc/nginx/nginx.conf /etc/nginx/nginx.conf
    systemctl restart nginx
  else
    cp ressources/etc/nginx/librephotos /etc/nginx/sites-available/librephotos
    ln -s /etc/nginx/sites-available/librephotos /etc/nginx/sites-enabled/
fi
echo Your ADMIN_PASS stored in /tmp/ADMIN_PASS Memorize it now and delete this file.
echo ADMIN_PASS=${ADMIN_PASS}
echo If system has the nginx server before installing librephotos, edit virtual host /etc/nginx/librephotos and restart nginx.
