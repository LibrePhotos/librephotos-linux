#!/usr/bin/env bash
set -exa

# PRE INSTALL
id -g librephotos > /dev/null || groupadd -r librephotos
id -u librephotos > /dev/null || useradd --home-dir /usr/lib/librephotos --comment "librephotos user" -g librephotos -mr -s /usr/sbin/nologin librephotos

export BASE_DATA=/var/lib/librephotos
export BASE_LOGS=/var/log/librephotos

mkdir -p $BASE_LOGS
mkdir -p $BASE_DATA/{data_models/places365,data_models/im2txt,data/nextcloud_media,protected_media}
chown -R librephotos:librephotos $BASE_LOGS
chown -R librephotos:librephotos $BASE_DATA

# LIBREPHOTOS : BACKEND

apt install --no-install-recommends -y \
swig libpq-dev postgresql-common curl libopenblas-dev libmagic1 libboost-all-dev libxrender-dev \
liblapack-dev git bzip2 cmake build-essential libsm6 libglib2.0-0 libgl1-mesa-glx gfortran gunicorn \
libheif-dev libssl-dev rustc liblzma-dev python3 python3-pip

su - -s $(which bash) librephotos << EOF
curl -SL https://s3.eu-central-1.amazonaws.com/ownphotos-deploy/places365_model.tar.gz | tar -zxC $BASE_DATA/data_models/places365/
curl -SL https://s3.eu-central-1.amazonaws.com/ownphotos-deploy/im2txt_model.tar.gz | tar -zxC $BASE_DATA/data_models/im2txt/
curl -SL https://s3.eu-central-1.amazonaws.com/ownphotos-deploy/im2txt_data.tar.gz | tar -zxC $BASE_DATA/data_models/im2txt/
mkdir -p ~/.cache/torch/hub/checkpoints/
curl -SL https://download.pytorch.org/models/resnet152-b121ed2d.pth -o ~/.cache/torch/hub/checkpoints/resnet152-b121ed2d.pth

pip3 install torch==1.7.1+cpu torchvision==0.8.2+cpu -f https://download.pytorch.org/whl/torch_stable.html
pip3 install -v --install-option="--no" --install-option="DLIB_USE_CUDA" --install-option="--no" --install-option="USE_AVX_INSTRUCTIONS" --install-option="--no" --install-option="USE_SSE4_INSTRUCTIONS" dlib

git clone https://github.com/tomamplius/librephotos backend
cd backend
pip3 install -r requirements.txt
python3 -m spacy download en_core_web_sm
EOF

# LIBREPHOTOS : FRONTEND

apt-get install -y curl git xsel nodejs git npm --no-install-recommends

su - -s $(which bash) librephotos << 'EOF'
git clone https://github.com/LibrePhotos/librephotos-frontend frontend
cd frontend
npm install
npm run build
npm install serve
EOF

# LIBREPHOTOS : PROXY

apt install -y nginx
cp ressources/etc/nginx/nginx.conf /etc/nginx/nginx.conf
systemctl restart nginx

# POST INSTALL

[ -d /usr/lib/librephotos/bin ] || mkdir -p /usr/lib/librephotos/bin
cp ressources/bin/* /usr/lib/librephotos/bin/
ln -fs /usr/lib/librephotos/bin/librephotos-cli /usr/sbin/librephotos-cli
chown -R librephotos:librephotos  /usr/lib/librephotos/bin/
cp -r ressources/etc/librephotos/ /etc/
cp ressources/systemd/* /etc/systemd/system/

systemctl enable librephotos-frontend
systemctl enable librephotos-backend
systemctl enable librephotos-worker.service
systemctl enable librephotos-image-similarity.service
