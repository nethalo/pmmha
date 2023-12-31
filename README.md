# PMM - High Availability
![](https://www.percona.com/wp-content/uploads/2023/01/Groupdocs-icons-3.svg)

Percona Monitoring and Management High Availability - PMM HA 

![](https://github.com/nethalo/pmmha/blob/513e4000a4fc73251b495e475d00fcc7eb708219/replica.gif)

This method provides means to:

- Use a running PMM instance
- Prepare it to act as a Primary
- Install a second PMM on a different machine
- Prepare it to act as a Secondary
- Establish replication

## Prerequisites

- Docker 23.0.3 and higher
- Docker installation will fail if on Amazon Linux or RHEL9/EL9 (unless you are on a s390x architecture machine), since the [Percona Easy-Install script](https://docs.percona.com/percona-monitoring-and-management/setting-up/server/easy-install.html) relies on the [Get Docker](https://get.docker.com/) script for the docker install. You will need to install docker on your own on those cases
- SSH Access to the host servers
- sudo capabilities
- Ports 443 and 9000 accessible from outside the Primary host machine

## Install & Run

Clone the repo and run the pmm.sh server

```bash
git clone https://github.com/nethalo/pmmha.git
cd pmmha
bash pmm.sh
```
You will be presented with the available options. First one is straightforward: Install PMM from scratch.

### Set Primary & Replica

Both Primary and Replica requires some preparation. Follow the steps below:

| Setup a Replica | Setup a Primary
|------|------|
|    <br>Choose the option **Set PMM Replica**:<br> <img src="media/setpmmreplica.png" alt="Set Replica" width="220" height="100" /> |   <br>Choose the option **Set PMM Primary**:<br><img src="media/setpmmprimary.png" alt="Set Primary" width="220" height="100" /> | 
|    <br>**Confirm**<br><img src="media/confirmset.png" alt="Confirm Replica" width="220" height="80" /><br> | **<--- Confirm** | 
|    <br>Enter the info for Host, User and Password of the Primary PMM<br><img src="media/inputexample.png" alt="Input" width="300" height="150" /> | No additional info needed :) | 
|    <br><br>Steps will be performed<br><img src="media/replicasteps.png" alt="Primary Steps" width="400" height="240" /> <br>Wait for the steps to finish and you are all set!<br>    |    Confirm it and steps will be performed<br><img src="media/primarysteps.png" alt="Primary Steps" width="400" height="200" /> <br>You are all set!   |

## What is under the hood?

Simply put, there are 3 main things replicated: 

- VictoriaMetrics time series data
- Inventory+conf info from PostgreSQL
- ClickHouse metrics table
- SQLite info: Grafana Dashboards/Users/Roles/etc, Alerts, PMM Managed Backups (for MongoDB)

### VictoriaMetrics

Federation is what is being used. A new scrape is configured tothe gather metrics via federate from the primary and stores it locally on the secondary:

```yaml
scrape_configs:
  - job_name: pmmha
    honor_timestamps: true
    scrape_interval: 2s
    scrape_timeout: 1s
    metrics_path: /prometheus/federate?match[]={__name__=~".*"}
    scheme: $scheme
    tls_config:
      insecure_skip_verify: true
    basic_auth:
      username: $user
      password: $pass
    static_configs:
      - targets:
          - "$host:$port"
```

### PostgreSQL

A pg_dump of the pmm-managed schema is made, stored into a FILE table inside the primary ClickHouse and the Secondary will read the contents of that table via the REMOTE function of ClickHouse and will restore the dump.

The FILE table is defined as

`CREATE TABLE IF NOT EXISTS pmm.pgpmm (dump String) ENGINE = File(RawBLOB);`

And the dump is

```bash
pg_dump -Upmm-managed --dbname=pmm-managed --inserts --data-only --disable-triggers > /srv/clickhouse/data/pmm/pgpmm/data.RawBLOB
```

### ClickHouse

For QAN data, the same REMOTE functionality is used. However, to achieve data Deduplication, an intermediate table is created with the engine ReplacingMergeTree so that way when forcing a Merge, data is consolidated. 

The remote functionality is a simple as this query

`select * from remote('$pmmserver', pmm.metrics)`

### SQLite

Again, For SQLite data, the same REMOTE functionality is used.

Dump is made per table to divide the dashboard ones from the rest, due to size

```bash
sqlite3 /srv/grafana/grafana.db ".dump --nosys --data-only --newlines --preserve-rowids dashboard dashboard_version" > /srv/clickhouse/data/pmm/sqlitedash/data.RawBLOB
```

The remote functionality is a simple as this query

```bash
clickhouse-client --format=PrettySpaceNoEscapes --multiquery --database pmm --query="SET output_format_pretty_max_rows=10000000000000; SET output_format_pretty_max_column_pad_width=10; SET output_format_pretty_max_value_width=100000000; select * from remote('$pmmserver', pmm.sqlitedash)"
```
