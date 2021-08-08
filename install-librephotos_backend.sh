#!/usr/bin/env bash
set -ea

# PRE INSTALL
id -g librephotos > /dev/null || groupadd -r librephotos
id -u librephotos > /dev/null || useradd --home-dir /usr/lib/librephotos --comment "librephotos user" -g librephotos -mr -s /usr/sbin/nologin librephotos

export BASE_DATA=/foto
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
cd
wget https://github.com/libvips/libvips/releases/download/v8.11.2/vips-8.11.2.tar.gz
tar xf vips-8.11.2.tar.gz
cd vips-8.11.2
./configure
make
make install
ldconfig
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib' >>  /usr/lib/librephotos/.bashrc

su - -s $(which bash) librephotos << EOF
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/places365.tar.gz | tar -zxC $BASE_DATA/data_models/
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/im2txt.tar.gz | tar -zxC $BASE_DATA/data_models/
mkdir -p ~/.cache/torch/hub/checkpoints/
curl -SL https://download.pytorch.org/models/resnet152-b121ed2d.pth -o ~/.cache/torch/hub/checkpoints/resnet152-b121ed2d.pth

pip3 install torch==1.7.1+cpu torchvision==0.8.2+cpu -f https://download.pytorch.org/whl/torch_stable.html
pip3 install -v --install-option="--no" --install-option="DLIB_USE_CUDA" dlib

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
rm /tmp/database_pass

systemctl enable librephotos-backend
systemctl enable librephotos-worker.service
systemctl enable librephotos-image-similarity.service

/usr/lib/librephotos/bin/librephotos-upgrade
