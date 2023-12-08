#!/bin/bash

while true; do
  # Your command here
  echo "Running pg_dump -Ugrafana --dbname=grafana --inserts --disable-trigger --exclude-table=user_auth_token -c > /srv/clickhouse/data/pmm/pggrafana/data.RawBLOB"
  pg_dump -Ugrafana --dbname=grafana --inserts --disable-trigger --exclude-table=user_auth_token -c > /srv/clickhouse/data/pmm/pggrafana/data.RawBLOB
  echo $?
  sleep 1m
done
