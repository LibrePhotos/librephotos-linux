#!/usr/bin/env bash

######################### HERE EDIT VARIABLES ################################################
# the location of photos. If changed here, also must change the path in thenginx virtual host.
# /etc/nginx
export PHOTOS=/var/lib/librephotos/photos
export BASE_DATA=/var/lib/librephotos/data
# If your hardware without AVX and SSE instructions, seach in this file by keyword
# 'dlib' and read instructions :) Modern system have these

######## Below change ONLY if you know what are you doing. #####################
# Front-end’s IPs from which allowed to handle set secure headers. (comma separate).
# Ref: https://docs.gunicorn.org/en/stable/settings.html#forwarded-allow-ips
# Ref2: https://github.com/benoitc/gunicorn/issues/1857
# '*' to disable
export FORWARDED_ALLOW_IPS=

# Postgresql connection settings
DB_HOST=localhost
DB_PORT=5432

# REDIS connection settings. Unnecessary settings comment with TWO SYMBOLS "\#" or delete.
# If connection to REDIS  using sock, set REDIS sock permissions to 770 and restart it.
# Script adds librephotos to redis group.
# for sock connection leave uncommented only REDIS_PATH, all other settings comment out.
REDIS=( \#REDIS_PASS= \#REDIS_DB= REDIS_HOST=localhost REDIS_PORT=6379 \#REDIS_PATH=/run/redis/redis-server.sock )

# If postgresql server is NOT local, after installation remove from these files
# /etc/systemd/system/librephotos-backend.service
# /etc/systemd/system/librephotos-worker.service
# these settings:
# postgresql.service
# Requires=postgresql.service

# If CPU supports SSE2, AVX, find in the script FFTW and uncomment configure settings
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

# CREATING DATABASE
REQUIRED_PKG=(postgresql)
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done
if [ -z ${dockerdeploy} ]; then
echo "Regular deploy";
else
ENV PG /var/lib/pgsql/data
sed -i -e "s/.*listen_addresses.*/listen_addresses = '${LISTEN}'/" $PG/postgresql.conf;
sed -i -e "s/.*host.*ident/# &/" $PG/pg_hba.conf;
fi
systemctl start postgresql.service
systemctl enable postgresql.service
su - postgres << EOF
psql -c 'DROP DATABASE IF EXISTS librephotos;'
psql -c 'DROP USER IF EXISTS librephotos;'
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


# LIBREPHOTOS : BACKEND

REQUIRED_PKG=( wget swig ffmpeg libimage-exiftool-perl libpq-dev  curl libopenblas-dev libmagic1 libboost-all-dev libxrender-dev \
liblapack-dev git bzip2 cmake build-essential libsm6 libglib2.0-0 libgl1-mesa-glx gfortran gunicorn \
libheif-dev libssl-dev rustc liblzma-dev python3 python3-pip imagemagick redis-server )
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

#Optimal. FFTW library. Fourier Transform can be used in the image edtion. Filters, effects, etc. Librephotos have not (yet) these features.
#wget http://fftw.org/fftw-3.3.10.tar.gz
#tar xf fftw-3.3.10.tar.gz
#cd fftw-3.3.10
# FFTW. if CPU support sse2, avx, uncomment below.
# More info about optimization: http://fftw.org/fftw3_doc/Installation-on-Unix.html
#./configure --enable-threads --with-pic #--enable-sse2 --enable-avx
#make -j$(nproc --all)
#make install
#ldconfig
#cd ..

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
echo "VIPS allready found on the system"
echo "Sometimes older vips can cause problems."
read -t 5 -p "If librephotos-backend not starting, try to uninstall vips and recompile again"
fi

su - -s $(which bash) librephotos << EOF
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/places365.tar.gz | tar -zxC $BASE_DATA/data_models/
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/im2txt.tar.gz | tar -zxC $BASE_DATA/data_models/
curl -SL https://github.com/LibrePhotos/librephotos-docker/releases/download/0.1/clip-embeddings.tar.gz | tar -zxC $BASE_DATA/data_models/
mkdir -p ~/.cache/torch/hub/checkpoints/
curl -SL https://download.pytorch.org/models/resnet152-b121ed2d.pth -o ~/.cache/torch/hub/checkpoints/resnet152-b121ed2d.pth
pip3 install torch==1.7.1+cpu torchvision==0.8.2+cpu -f https://download.pytorch.org/whl/torch_stable.html
#################################################################################################
# Here seting up AVX and SSE support.
# Comment out first line 'pip3 install...' and uncoment second. Must leave only one.
##################################################################################################
pip3 install -v --install-option="--no" --install-option="DLIB_USE_CUDA" dlib
#pip3 install -v --install-option="--no" --install-option="DLIB_USE_CUDA" --install-option="--no" --install-option="USE_AVX_INSTRUCTIONS" --install-option="--no" --install-option="USE_SSE4_INSTRUCTIONS" dlib
#This does only support x64 and not ARM. To install for ARM you have to build it from source
pip3 install faiss-cpu
pip3 install pyvips
git clone https://github.com/LibrePhotos/librephotos.git backend
cd backend
pip3 install -r requirements.txt
EOF

# POST INSTALL

usermod -aG redis librephotos
[ -d /usr/lib/librephotos/bin ] || mkdir -p /usr/lib/librephotos/bin
cp ressources/bin/* /usr/lib/librephotos/bin/
ln -fs /usr/lib/librephotos/bin/librephotos-cli /usr/sbin/librephotos-cli
chown -R librephotos:librephotos  /usr/lib/librephotos/bin/
cp -r ressources/etc/librephotos/ /etc/
cp ressources/systemd/* /etc/systemd/system/

sed -i "s|DB_PASS=password|DB_PASS=${pass}|g" /etc/librephotos/librephotos-backend.env
secret_key=$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-16};)
sed -i "s|SECRET_KEY=SecretKeyToBeDefined|SECRET_KEY=${secret_key}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|BASE_DATA=|BASE_DATA=${BASE_DATA}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|MAPBOX_API_KEY=|MAPBOX_API_KEY=${MAPBOX_API_KEY}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|FORWARDED_ALLOW_IPS=|FORWARDED_ALLOW_IPS=${FORWARDED_ALLOW_IPS}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|DB_HOST=|DB_HOST=${DB_HOST}|g" /etc/librephotos/librephotos-backend.env
sed -i "s|DB_PORT=|DB_PORT=${DB_PORT}|g" /etc/librephotos/librephotos-backend.env
for i in "${REDIS[@]}"; do
  echo $i >> /etc/librephotos/librephotos-backend.env
done
rm /tmp/database_pass

systemctl start librephotos-worker.service && systemctl start librephotos-backend && systemctl start librephotos-image-similarity.service && echo
systemctl enable librephotos-backend
systemctl enable librephotos-worker.service
systemctl enable librephotos-image-similarity.service

# LIBREPHOTOS : FRONTEND
REQUIRED_PKG=( curl git xsel git )
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done

[ $(dpkg-query -W -f='${Status}' nodejs 2>/dev/null | grep -c "ok installed") -eq 0 ] && \
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash - && apt install nodejs -y --no-install-recommends
npm install -g yarn
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
/usr/lib/librephotos/bin/librephotos-upgrade

# NGINX REVERSE PROXY

if [ $(dpkg-query -W -f='${Status}' nginx* 2>/dev/null | grep -c "ok installed") -eq 0 ];
  then
    apt install -y nginx
    cp ressources/etc/nginx/nginx.conf /etc/nginx/nginx.conf
    systemctl restart nginx
  else
    cp ressources/etc/nginx/librephotos /etc/nginx/sites-available/librephotos
    ln -s /etc/nginx/sites-available/librephotos /etc/nginx/sites-enabled/
fi
echo "If system has the nginx server before installing librephotos, edit virtual host /etc/nginx/librephotos and restart nginx."
echo "Optimal: check other settings in the file /etc/librephotos/librephotos-backend.env"
echo "After changing BASE_DATA, must edit file /etc/nginx/nginx.conf or /etc/nginx/sites-available/librephotos and change accordinaly"
echo "alias. There  4 lines"-
