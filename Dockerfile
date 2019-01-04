FROM alpine:3.8

ENV \
  ETCD_VER=v3.3.10 \
  ETCD_SHA256=1620a59150ec0a0124a65540e23891243feb2d9a628092fb1edcc23974724a45 \
  DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download \
  \
  ETCD_HEARTBEAT_INTERVAL=1000 \
  ETCD_ELECTION_TIMEOUT=5000 \
  ETCD_SNAPSHOT_COUNT=5000 \
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
