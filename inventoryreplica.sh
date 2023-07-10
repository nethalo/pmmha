#!/bin/bash

pmmserver=$(cat /srv/pmmserver.txt)

while true; do
  # Your command here
  echo "Running time clickhouse-client -E --database pmm --query=\"select * from remote('$pmmserver', pmm.pgpmm)\" > /tmp/pgpmm.sql"
  clickhouse-client -E --database pmm --query="select * from remote('$pmmserver', pmm.pgpmm)" > /tmp/pgpmm.sql
  echo $?
  echo "Running time psql -Upmm-managed --dbname=pmm-managed -f /tmp/pgpmm.sql"
  psql -Upmm-managed --dbname=pmm-managed -f /tmp/pgpmm.sql &> /dev/null
  echo $?
  echo "Running e psql -Upmm-managed --dbname=pmm-managed -c  \"update agents set disabled = 't'\""
  psql -Upmm-managed --dbname=pmm-managed -c  "update agents set disabled = 't'"
  echo $?
  sleep 15m
done