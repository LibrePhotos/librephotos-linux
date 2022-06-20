FROM ubuntu:impish
ENV DEBIAN_FRONTEND noninteractive
ENV DOCKERDEPLOY true
RUN apt-get update && apt-get install -y systemd
RUN apt-get install gosu
COPY docker/systemctl.py /usr/bin/systemctl.py
RUN chmod +x /usr/bin/systemctl.py \
    && cp -f /usr/bin/systemctl.py /usr/bin/systemctl
COPY . librephotos-linux
WORKDIR /librephotos-linux
RUN ./install-librephotos.sh
ENV PGDATA /var/lib/postgresql/data
ENV POSTGRES_USER docker
ENV POSTGRES_PASSWORD AaAa1234
ENV POSTGRES_DB librephotos
RUN mkdir /docker-entrypoint-initdb.d
COPY ./docker/postgres-entrypoint.sh /usr/local/bin/
RUN chmod +rx /usr/lib/librephotos/bin/librephotos-worker
RUN chmod +rx /usr/local/bin/postgres-entrypoint.sh
# this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
EXPOSE 3000
CMD ["/bin/bash","./docker/entrypoint.sh"]
