FROM ubuntu:hirsute
ENV DEBIAN_FRONTEND noninteractive
COPY . librephotos-linux
WORKDIR /librephotos-linux
RUN apt update
RUN ./install-librephotos.sh
EXPOSE 3000