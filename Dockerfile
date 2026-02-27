FROM docker.io/library/ubuntu:noble

LABEL org.opencontainers.image.authors="moulickaggarwal"
LABEL org.opencontainers.image.source="https://github.com/Moulick/debug-image"
LABEL org.opencontainers.image.title="debug-image"

ARG TARGETARCH
ARG TARGETOS
ARG TARGETPLATFORM

RUN echo "TARGETARCH: ${TARGETARCH}" && \
    echo "TARGETOS: ${TARGETOS}" && \
    echo "TARGETPLATFORM: ${TARGETPLATFORM}"

ENV DEBIAN_FRONTEND="noninteractive"

# Clean up APT when done.
RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
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
  rsync \
  python3 \
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
  ssh \
  iptables \
  kafkacat \
  net-tools \
  nmap \
  && \
  apt-get clean && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.10 /uv /uvx /bin/
RUN uv pip install --system --break-system-packages --no-cache-dir --upgrade s3cmd==2.4.0 python-magic

# https://download.docker.com/linux/static/stable/
# renovate: datasource=docker depName=docker packageName=docker versioning=docker
ENV DOCKER_VERSION=28.5.0
RUN curl -L "https://download.docker.com/linux/static/stable/$(uname -m)/docker-${DOCKER_VERSION}.tgz" \
  | tar -zxvf - --strip 1 -C /usr/bin docker/docker

RUN curl -lo awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" && \
  unzip -q awscliv2.zip && \
  ./aws/install && \
  rm -R awscliv2.zip ./aws && \
  aws --version

# https://github.com/hatoo/oha/releases
# renovate: datasource=github-releases depName=oha packageName=hatoo/oha versioning=semver-coerced
ENV OHA_VERSION=v1.13.0
RUN curl -Lo /usr/local/bin/oha "https://github.com/hatoo/oha/releases/download/${OHA_VERSION}/oha-linux-${TARGETARCH}" && \
  chmod +x /usr/local/bin/oha && \
  oha --version

# https://github.com/mikefarah/yq/releases/
# renovate: datasource=github-releases depName=yq packageName=mikefarah/yq
ENV YQ_VERSION=v4.52.4
RUN curl -Lo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_$TARGETARCH" && \
  chmod +x /usr/local/bin/yq && \
  yq --version

# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
# renovate: datasource=github-releases depName=kubectl packageName=kubernetes/kubernetes
ENV KUBECTL_VERSION=v1.34.0
RUN curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/$TARGETARCH/kubectl" && \
  chmod +x /usr/local/bin/kubectl && \
  kubectl version --client=true

# https://github.com/helm/helm/releases
# renovate: datasource=github-releases depName=helm packageName=helm/helm
ENV HELM_VERSION=v4.1.1
RUN curl -L "https://get.helm.sh/helm-$HELM_VERSION-linux-$TARGETARCH.tar.gz" \
  | tar -zxvf - --strip-components=1 -C /usr/local/bin linux-$TARGETARCH/helm && \
  chmod +x /usr/local/bin/helm && \
  helm version

# https://github.com/fullstorydev/grpcurl/releases
# renovate: datasource=github-releases depName=grpcurl packageName=fullstorydev/grpcurl
ENV GRPCURL_VERSION=v1.9.2
RUN GRPCURL_ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "x86_64" || echo "${TARGETARCH}") && \
  curl -L "https://github.com/fullstorydev/grpcurl/releases/download/${GRPCURL_VERSION}/grpcurl_${GRPCURL_VERSION#v}_linux_${GRPCURL_ARCH}.tar.gz" \
  | tar -zxvf - -C /usr/local/bin grpcurl && \
  chmod +x /usr/local/bin/grpcurl && \
  grpcurl --version

# https://github.com/kubernetes-sigs/kustomize/releases
# renovate: datasource=github-releases depName=kustomize packageName=kubernetes-sigs/kustomize
ENV KUSTOMIZE_VERSION=v5.8.1
RUN curl -L "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" \
  | tar -zxvf - -C /usr/local/bin kustomize && \
  chmod +x /usr/local/bin/kustomize && \
  kustomize version
