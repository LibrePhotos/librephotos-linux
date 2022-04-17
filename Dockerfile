FROM ubuntu:hirsute
ENV DEBIAN_FRONTEND noninteractive
COPY docker/systemctl.py /usr/bin/systemctl
RUN chmod 666 /usr/bin/systemctl
COPY . librephotos-linux
WORKDIR /librephotos-linux
RUN apt update
RUN ./install-librephotos.sh
EXPOSE 3000
