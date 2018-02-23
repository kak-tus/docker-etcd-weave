FROM alpine:3.7

ENV \
  ETCD_VER=v3.2.16 \
  ETCD_SHA256=b664649bdc5e67bc79cda7f0d77156fdd31c8742a9e5335c3f16cb7119da4ec5 \
  DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download \
  \
  ETCD_HEARTBEAT_INTERVAL=500 \
  ETCD_ELECTION_TIMEOUT=5000 \
  \
  ETCD_WEAVE_IP=

RUN \
  apk add --no-cache \
    curl \
    jq \
  \
  && curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz \
  && echo -n "$ETCD_SHA256  /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz" | sha256sum -c - \
  && mkdir -p /tmp/etcd \
  && tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd \
  && cp /tmp/etcd/etcd-${ETCD_VER}-linux-amd64/etcd /usr/local/bin \
  && rm -rf /tmp/etcd \
  && rm /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

COPY weave-discovery.sh /usr/local/bin/weave-discovery.sh

VOLUME /data

CMD ["/usr/local/bin/weave-discovery.sh"]
