FROM alpine:3.4

MAINTAINER Andrey Kuzmin "kak-tus@mail.ru"

ENV ETCD_VER=v3.0.15
ENV DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download

RUN \
  apk add --update-cache curl drill jq \

  && curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz \
  && mkdir -p /tmp/etcd \
  && tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd \
  && cp /tmp/etcd/etcd-${ETCD_VER}-linux-amd64/etcd /usr/local/bin \
  && rm -rf /tmp/etcd \
  && rm /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz \

  && rm -rf /var/cache/apk/*

COPY weave-discovery.sh /usr/local/bin/weave-discovery.sh

VOLUME /data

CMD /usr/local/bin/weave-discovery.sh
