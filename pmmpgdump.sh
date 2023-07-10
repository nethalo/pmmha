#!/bin/bash

while true; do
  # Your command here
  echo "Running pg_dump -Upmm-managed --dbname=pmm-managed --inserts --data-only --disable-triggers > /srv/clickhouse/data/pmm/pgpmm/data.RawBLOB"
  pg_dump -Upmm-managed --dbname=pmm-managed --inserts --data-only --disable-triggers > /srv/clickhouse/data/pmm/pgpmm/data.RawBLOB
  echo $?
  sleep 30m
done
