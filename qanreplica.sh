#!/bin/bash

pmmserver=$(cat /srv/pmmserver.txt)

while true; do
  # Your command here
  echo "Running clickhouse-client --database pmm --multiquery --query=\"truncate table metrics_replica; insert into metrics_replica select * from metrics; insert into metrics_replica select * from remote('$pmmserver', pmm.metrics) where service_name not like 'pmm-server-postgresql'; optimize table metrics_replica\""
  clickhouse-client --database pmm --multiquery --query="truncate table metrics_replica; insert into metrics_replica select * from metrics; insert into metrics_replica select * from remote('$pmmserver', pmm.metrics) where service_name not like 'pmm-server-postgresql'; optimize table metrics_replica"
  echo $?
  echo "Running  clickhouse-client --database pmm --multiquery --query=\"insert into metrics select * from metrics_replica;\""
  clickhouse-client --database pmm --multiquery --query="insert into metrics select * from metrics_replica;"
  echo $?
  sleep 30m
done
