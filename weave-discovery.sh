#!/usr/bin/env sh

rm -rf /data/*

# Wait for weave DNS register
sleep 5

retry_times=3
wait_time=1

ip=$( hostname -i | awk '{print $1}')
echo "Our IP $ip"

ips=$( drill etcd.weave.local | fgrep IN | fgrep -v ';' | awk '{print $5}' | grep -E -o '^[0-9\.]+$' | tr "\n" "," | sed 's/,$//' )
echo "Discovered ips $ips"

etcd_existing_peer_urls=
etcd_existing_peer_names=
etcd_good_member_ip=
etcd_members=

for i in $( echo $ips | tr "," "\n" ); do
  etcd_members=$( curl -f -s http://$i:2379/v2/members )

  if [ -n "$etcd_members" ]; then
    etcd_good_member_ip="$i"
    echo "etcd_members=$etcd_members"

    etcd_existing_peer_urls=$( echo "$etcd_members" | jq --raw-output .[][].peerURLs[0] )
    etcd_existing_peer_names=$( echo "$etcd_members" | jq --raw-output .[][].name )
    break
  fi
done

echo "etcd_good_member_ip=$etcd_good_member_ip"
echo "etcd_existing_peer_urls=$etcd_existing_peer_urls"
echo "etcd_existing_peer_names=$etcd_existing_peer_names"

initial_cluster_state=
initial_cluster=

add_ok=201
already_added=409
delete_ok=204
delete_gone=410

if [ -n "$etcd_good_member_ip" ]; then
  echo "joining existing cluster"

  for i in $( echo $etcd_existing_peer_names ); do
    is_bad_peer="1"

    for j in $( echo $ips | tr "," "\n" ); do
      if [ "$i" = "$j" ]; then
        is_bad_peer=""
      fi
    done

    if [ -n "$is_bad_peer" ]; then
      echo "Bad peer found $i"
      bad_peer_id=$( echo "$etcd_members" | jq --raw-output ".[] | map(select(.name==\"$i\")) | .[].id" )

      if [ -n "$bad_peer_id" ]; then
        echo "Bad peer id found $bad_peer_id"

        status=0
        retry=1

        until [ "$status" = "$delete_ok" ] || [ "$status" = "$delete_gone" ] || [ "$retry" = "$retry_times" ]; do
          status=$( curl -f -s -w %{http_code} "http://$etcd_good_member_ip:2379/v2/members/$bad_peer_id" -XDELETE)
          echo "removing bad peer $i, retry $((retry++)), return code $status."
          sleep $wait_time
        done

        if [ "$status" != "$delete_ok" ] && [ "$status" != "$delete_gone" ]; then
          echo "ERROR: failed to remove bad peer: $i, return code $status."
        else
          echo "removed bad peer: $i, return code $status."
        fi
      else
        echo "Bad peer id not found"
      fi
    fi
  done

  initial_cluster_state=existing

  initial_cluster="$ip=http://$ip:2380"

  for i in $( echo $etcd_existing_peer_names | tr "," "\n" ); do
    initial_cluster="$initial_cluster,$i=http://$i:2380"
  done

  initial_cluster=$( echo $initial_cluster | sed 's/,$//' | sed 's/^,//' )

  status=0
  retry=1

  until [ "$status" = "$add_ok" ] || [ "$status" = "$already_added" ] || [ "$retry" = "$retry_times" ]; do
    status=$( curl -f -s -w %{http_code} -o /dev/null -XPOST "http://$etcd_good_member_ip:2379/v2/members" -H "Content-Type: application/json" -d "{\"clientURLs\": [\"http://$ip:2379\"], \"peerURLs\": [\"http://$ip:2380\"], \"name\": \"$ip\"}" )
    echo "adding IP $ip, retry $((retry++)), return code $status."
    sleep $wait_time
  done

  if [ "$status" != "$add_ok" ] && [ "$status" != "$already_added" ]; then
    echo "unable to add $ip to the cluster: return code $status."
    # exit 9
  else
    echo "added $ip to existing cluster, return code $status"
  fi
else
  echo "creating new cluster"
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
  --initial-cluster-token etcd-cluster &

child=$!

trap "kill $child" INT TERM
wait "$child"
