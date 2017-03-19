FROM alpine:3.5

ENV ETCD_VER=v3.1.3
ENV ETCD_SHA256=ae3c5ac1e78be8ef2a3ecf985d5300f4e02abafcd5b75cc885b18e2ba31a7ba4
ENV DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download

RUN \
  apk add --no-cache curl drill jq \

  && curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz \
  && echo -n "$ETCD_SHA256  /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz" | sha256sum -c - \
  && mkdir -p /tmp/etcd \
  && tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd \
  && cp /tmp/etcd/etcd-${ETCD_VER}-linux-amd64/etcd /usr/local/bin \
  && rm -rf /tmp/etcd \
  && rm /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

COPY weave-discovery.sh /usr/local/bin/weave-discovery.sh

VOLUME /data

ENV ETCD_HEARTBEAT_INTERVAL=500
ENV ETCD_ELECTION_TIMEOUT=5000

CMD ["/usr/local/bin/weave-discovery.sh"]
