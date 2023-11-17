#!/bin/bash

pmmserver=$(cat /srv/pmmserver.txt)

while true; do
  # Your command here
  echo "Running time clickhouse-client -E --database pmm --query=\"select * from remote('$pmmserver', pmm.pggrafana)\" > /tmp/pggrafana.sql"
  clickhouse-client -E --database pmm --query="select * from remote('$pmmserver', pmm.pggrafana)" > /tmp/pggrafana.sql
  echo $?
  echo "Running time psql -Ugrafana --dbname=grafana -f /tmp/pggrafana.sql"
  psql -Ugrafana --dbname=grafana -f /tmp/pggrafana.sql &> /dev/null
  echo $?
  sleep 2m
done
