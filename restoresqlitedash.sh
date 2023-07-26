#!/bin/bash

pmmserver=$(cat /srv/pmmserver.txt)

while true; do
  # Your command here
  echo "Running clickhouse-client --format=PrettySpaceNoEscapes --multiquery --database pmm --query=\"SET output_format_pretty_max_rows=10000000000000; SET output_format_pretty_max_column_pad_width=10; SET output_format_pretty_max_value_width=100000000; select * from remote('$pmmserver', pmm.sqlitedash)\" > /tmp/sqlitedash.sql"
  clickhouse-client --format=PrettySpaceNoEscapes --multiquery --database pmm --query="SET output_format_pretty_max_rows=10000000000000; SET output_format_pretty_max_column_pad_width=10; SET output_format_pretty_max_value_width=100000000; select * from remote('$pmmserver', pmm.sqlitedash)" > /tmp/sqlitedash.sql
  echo $?
  echo "Running sqlite3 /srv/grafana/grafana.db < /tmp/sqlitedash.sql &> /dev/null"
  sqlite3 /srv/grafana/grafana.db < /tmp/sqlitedash.sql &> /dev/null
  echo $?
  sleep 20m
done
