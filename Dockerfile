FROM ubuntu:hirsute
ENV DEBIAN_FRONTEND noninteractive
COPY . librephotos-linux
WORKDIR /librephotos-linux
RUN sed -i '/sexport ADMINUSERNAME=/export ADMINUSERNAME=test/g' install-librephotos.sh
RUN sed -i '/sexport ADMINEMAIL=/export ADMINEMAIL=test@librephotos.com/g' install-librephotos.sh
RUN apt update
RUN ./install-librephotos.sh
