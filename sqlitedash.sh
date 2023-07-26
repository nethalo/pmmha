#!/bin/bash

while true; do
  # Your command here
  echo "Running sqlite3 /srv/grafana/grafana.db \".dump --nosys --data-only --newlines --preserve-rowids dashboard dashboard_version\" > /srv/clickhouse/data/pmm/sqlitedash/data.RawBLOB"
  sqlite3 /srv/grafana/grafana.db ".dump --nosys --data-only --newlines --preserve-rowids dashboard dashboard_version" > /srv/clickhouse/data/pmm/sqlitedash/data.RawBLOB
  echo $?
  sleep 30m
done
