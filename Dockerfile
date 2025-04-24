FROM docker.io/amd64/ubuntu:noble

# https://download.docker.com/linux/static/stable/x86_64/
ENV docker_url=https://download.docker.com/linux/static/stable/x86_64
ENV docker_version=28.1.1

# https://github.com/helm/helm/releases
ENV HELM_VERSION=v3.17.3

# https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
ENV KUBECTL_VERSION=1.32.0/2025-01-10

# https://github.com/mikefarah/yq/releases/
ENV YQ_VERSION=v4.45.1/yq_linux_amd64

ENV DEBIAN_FRONTEND="noninteractive"

LABEL org.opencontainers.image.authors="moulickaggarwal"
LABEL org.opencontainers.image.source="https://github.com/Moulick/debug-image"
LABEL org.opencontainers.image.title="debug-image"

# Clean up APT when done.
RUN apt update && \
  apt upgrade -y && \
  apt install -y --no-install-recommends \
  gnupg \
  ca-certificates \
  postgresql-client \
  mysql-client \
  ncat \
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
  wget \
  gettext \
  openssl \
  git \
  parallel \
  default-jre \
  ssh \
  iptables \
  kafkacat \
  net-tools \
  nmap \
  && \
  echo "deb [signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ stable main" | tee /etc/apt/sources.list.d/azlux.list && \
  wget -O /usr/share/keyrings/azlux-archive-keyring.gpg https://azlux.fr/repo.gpg && \
  apt update && \
  apt install oha -y && \
  apt clean && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* && \
  curl -fsSL $docker_url/docker-$docker_version.tgz | tar zxvf - --strip 1 -C /usr/bin docker/docker

RUN pip3 install --break-system-packages --no-cache-dir --upgrade s3cmd==2.4.0 python-magic

RUN curl -fsSlo awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" && \
  unzip -q awscliv2.zip && ./aws/install && rm -R awscliv2.zip ./aws && aws --version \
  && \
  cd /usr/local/bin && \
  curl -fsSLo yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}" && \
  curl -fsSLo kubectl "https://s3.us-west-2.amazonaws.com/amazon-eks/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
  curl -fsSLo helm.tar.gz "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz" && \
  tar -xzvf helm.tar.gz -C /tmp && mv /tmp/linux-amd64/helm . && rm helm.tar.gz && rm -R /tmp/linux-amd64 && \
  chmod +x yq && yq --version && \
  chmod +x kubectl && kubectl version --client=true && \
  chmod +x helm && helm version && \
  curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && \
  kustomize version
