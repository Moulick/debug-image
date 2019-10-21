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
    redis-tools \
    iputils-ping \
    screen \
    npm \
    zip \
    && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4 && \
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list && \
    add-apt-repository -y --no-update ppa:rmescandon/yq && \
    apt-get update -y && \
    apt-get install -y \
    mongodb-org-shell \
    mongodb-org-tools \
    yq && \
    pip install --upgrade awscli==1.16.260 s3cmd==2.0.2 python-magic && \
    apt-get clean && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* \
    && curl -fsSL $docker_url/docker-$docker_version.tgz | tar zxvf - --strip 1 -C /usr/bin docker/docker

RUN cd /usr/local/bin && \
    wget https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl && \
    wget https://get.helm.sh/helm-v2.15.0-linux-amd64.tar.gz && \
    tar -xzvf helm-v2.15.0-linux-amd64.tar.gz -C /tmp && \
    mv /tmp/linux-amd64/helm . && \
    rm -R /tmp/linux-amd64 && \
    chmod +x kubectl && \
    chmod +x helm

WORKDIR $HOME/somedir