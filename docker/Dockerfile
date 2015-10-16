FROM postgres:9.4

MAINTAINER Constantin Clauzel

RUN apt-get update && apt-get upgrade -y --force-yes && apt-get install -y --force-yes daemontools daemontools-run

RUN mkdir /service

ADD linux_amd64/parsemap /opt/bin/parsemap
ADD service/postgres /service/postgres
ADD service/parsemap /service/parsemap
ADD parsemap.crt /parsemap.crt
ADD parsemap.key /parsemap.key
ADD config.ini /etc/parsemap.ini

ADD docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ENV GIN_MODE=release

EXPOSE 80

CMD ["/usr/bin/svscan", "/service"]
