#!/usr/bin/env sh

retry_times=3
wait_time=1

ip="$ETCD_WEAVE_IP"
ips=$( cat /etc/etcd_ips.conf )

etcd_existing_peer_names=
etcd_good_member_ip=
etcd_members=

for i in $( echo $ips | tr "," "\n" ); do
  etcd_members=$( curl -f -s http://$i:2379/v2/members )

  if [ -n "$etcd_members" ]; then
    etcd_good_member_ip="$i"
    echo "etcd_members=$etcd_members"

    etcd_existing_peer_names=$( echo "$etcd_members" | jq --raw-output .[][].name )
    break
  fi
done

echo "etcd good member ip: $etcd_good_member_ip"
echo "etcd existing peer names: $etcd_existing_peer_names"

initial_cluster_state=
initial_cluster=

add_ok=201
already_added=409

if [ -n "$etcd_good_member_ip" ]; then
  echo "Joining existing cluster"

  initial_cluster_state=existing

  initial_cluster="$ip=http://$ip:2380"

  for i in $( echo $etcd_existing_peer_names | tr "," "\n" ); do
    if [ "$i" != "$ip" ]; then
      echo "Add $i to inital cluster"
      initial_cluster="$initial_cluster,$i=http://$i:2380"
    fi
  done

  initial_cluster=$( echo $initial_cluster | sed 's/,$//' | sed 's/^,//' )

  status=0
  retry=1

  until [ "$status" = "$add_ok" ] || [ "$status" = "$already_added" ] || [ "$retry" = "$retry_times" ]; do
    status=$( curl -f -s -w %{http_code} -o /dev/null -X POST "http://$etcd_good_member_ip:2379/v2/members" -H "Content-Type: application/json" -d "{\"clientURLs\": [\"http://$ip:2379\"], \"peerURLs\": [\"http://$ip:2380\"], \"name\": \"$ip\"}" )
    echo "Adding IP $ip, retry $((retry++)), return code $status."
    sleep $wait_time
  done

  if [ "$status" != "$add_ok" ] && [ "$status" != "$already_added" ]; then
    echo "Unable to add $ip to the cluster: return code $status."
  else
    echo "Added $ip to existing cluster, return code $status"
  fi
else
  echo "Creating new cluster"
  initial_cluster_state=new

  for i in $( echo $ips | tr "," "\n" ); do
    initial_cluster="$initial_cluster,$i=http://$i:2380"
  done

  initial_cluster=$( echo $initial_cluster | sed 's/,$//' | sed 's/^,//' )
fi

echo "Initial cluster $initial_cluster"
echo "Initial cluster state $initial_cluster_state"

etcd \
  --data-dir /data \
  --name $ip \
  --initial-cluster-state $initial_cluster_state \
  --initial-cluster $initial_cluster \
  --initial-advertise-peer-urls http://$ip:2380 \
  --listen-peer-urls http://0.0.0.0:2380 \
  --listen-client-urls http://0.0.0.0:2379 \
  --advertise-client-urls http://$ip:2379 \
  --initial-cluster-token etcd-cluster \
  --strict-reconfig-check \
  &

child=$!

trap "kill $child" INT TERM
wait "$child"
