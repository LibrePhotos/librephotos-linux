FROM ubuntu:hirsute
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get install systemd
COPY docker/systemctl.py /usr/bin/systemctl.py
RUN chmod +x /usr/bin/systemctl.py \
    && cp -f /usr/bin/systemctl.py /usr/bin/systemctl
RUN systemctl enable something
COPY . librephotos-linux
WORKDIR /librephotos-linux
RUN apt update
RUN ./install-librephotos.sh
EXPOSE 3000
