#!/usr/bin/env bash
set -exa

export BASE_DATA=/foto
export BASE_LOGS=/var/log/librephotos

# LIBREPHOTOS : FRONTEND
REQUIRED_PKG=( curl git xsel git )
for i in "${REQUIRED_PKG[@]}"; do
[ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ] && apt install --no-install-recommends -y $i
done

[ $(dpkg-query -W -f='${Status}' nodejs 2>/dev/null | grep -c "ok installed") -eq 0 ] && \
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash - && apt install nodejs -y --no-install-recommends

su - -s $(which bash) librephotos << EOF
git clone https://github.com/Seneliux/librephotos-frontend.git frontend
cd frontend
npm install
npm run build
npm install serve
EOF

systemctl enable librephotos-frontend
