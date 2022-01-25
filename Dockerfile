FROM ubuntu:latest
ENV docker_url=https://download.docker.com/linux/static/stable/x86_64
ENV docker_version=20.10.12
ENV DEBIAN_FRONTEND="noninteractive"

LABEL Maintainer="Moulick Aggarwal" Email="moulickaggarwal@gmail.com"

# Clean up APT when done.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    gnupg2 \
    ca-certificates \
    software-properties-common \
    postgresql-client \
    netcat \
    telnet \
    dnsutils \
    iputils-ping \
    nano \
    redis-tools \
    iputils-ping \
    screen \
    npm \
    rsync \
    python3 \
    python3-pip \
    zip \
    unzip \
    jq \
    groff \
    less \
    curl \
    gettext \
    openssl \
    git \
    wget \
    parallel \
    default-jre \
    ssh \
    iptables \
    && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4 && \
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list && \
    add-apt-repository -y --no-update ppa:rmescandon/yq && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
    mongodb-org-shell \
    mongodb-org-tools \
    yq \
    && \
    pip3 install --upgrade s3cmd==2.2.0 python-magic && \
    apt-get clean && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* \
    && curl -fsSL $docker_url/docker-$docker_version.tgz | tar zxvf - --strip 1 -C /usr/bin docker/docker

ENV HELM_VERSION=v3.8.0

RUN curl -o awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" && \
    unzip awscliv2.zip && \
    ls -lah && \
    ./aws/install && \
    # rm -R awscliv2.zip ./aws && \
    cd /usr/local/bin && \
    curl -o kubectl "https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl" && \
    curl -o helm.tar.gz "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz" && \
    curl -L -o amazonmq-cli.zip "https://github.com/antonwierenga/amazonmq-cli/releases/download/v0.2.2/amazonmq-cli-0.2.2.zip" && \
    unzip amazonmq-cli.zip -d $HOME/amazonmq-cli && \
    tar -xzvf helm.tar.gz -C /tmp && \
    rm helm.tar.gz && \
    mv /tmp/linux-amd64/helm . && \
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && \
    rm -R /tmp/linux-amd64 && \
    rm -R amazonmq-cli.zip && \
    chmod +x kubectl && \
    chmod +x helm && \
    chmod +x kustomize
