# Use phusion/baseimage as base image. To make your builds
# reproducible, make sure you lock down to a specific version, not
# to `latest`! See
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
# for a list of version numbers.
FROM ubuntu:latest
ENV docker_url=https://download.docker.com/linux/static/stable/x86_64
ENV docker_version=19.03.1

LABEL Maintainer="Moulick Aggarwal" Email="moulickaggarwal@gmail.com"

# Clean up APT when done.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    gnupg2 \
    ca-certificates \
    software-properties-common \
    postgresql-client \
    netcat \
    telnet \
    dnsutils \
    curl \
    jq \
    nano \
    && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4 && \
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list && \
    add-apt-repository -y --no-update ppa:rmescandon/yq && \
    apt-get update -y && \
    apt-get install -y \
    mongodb-org-shell \
    mongodb-org-tools \
    yq \
    && \
    apt-get clean && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* \
    && curl -fsSL $docker_url/docker-$docker_version.tgz | tar zxvf - --strip 1 -C /usr/bin docker/docker
