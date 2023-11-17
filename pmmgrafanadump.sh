#!/bin/bash

while true; do
  # Your command here
  echo "Running pg_dump -Ugrafana --dbname=grafana --inserts --data-only --disable-trigger > /srv/clickhouse/data/pmm/pggrafana/data.RawBLOB"
  pg_dump -Ugrafana --dbname=grafana --inserts --data-only --disable-trigger > /srv/clickhouse/data/pmm/pggrafana/data.RawBLOB
  echo $?
  sleep 1m
done
