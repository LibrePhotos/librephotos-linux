FROM ubuntu:hirsute
ENV DEBIAN_FRONTEND noninteractive
COPY docker/systemctl.py /usr/bin/systemctl.py
RUN cp -f /usr/bin/systemctl /usr/bin/systemctl.original \
    && chmod +x /usr/bin/systemctl.py \
    && cp -f /usr/bin/systemctl.py /usr/bin/systemctl
COPY . librephotos-linux
WORKDIR /librephotos-linux
RUN apt update
RUN ./install-librephotos.sh
EXPOSE 3000
