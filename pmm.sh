#!/bin/bash
# daniel.burgos@percona.com
#

clear
set -o pipefail

lockFile="/tmp/pmmsh.lock"
errorFile="/tmp/pmmsh.err"
logFile="/tmp/pmmsh.log"
scrapeyaml="scrape.yaml"

function logInfo (){

        echo "[$(date +%y%m%d-%H:%M:%S)] $1" >> $logFile
}

function sendAlert () {
        if [ -e "$errorFile" ]
        then
                alertMsg=$(cat $errorFile)
                echo -e "${alertMsg}" #| mailx -s "[$HOSTNAME] ALERT " "${email}"
        fi
}

function destructor () {
        sendAlert
        rm -f "$lockFile" "$errorFile"
}

# Setting TRAP in order to capture SIG and cleanup things
trap destructor EXIT INT TERM


function verifyExecution () {
        local exitCode="$1"
        local mustDie=${3-:"false"}
        if [ $exitCode -ne "0" ]
        then
                msg="[ERROR] Failed execution. ${2}"
                echo "$msg" >> ${errorFile}
                if [ "$mustDie" == "true" ]; then
                        exit 1
                else
                        return 1
                fi
        fi
        return 0
}

function setLockFile () {
        if [ -e "$lockFile" ]; then
                trap - EXIT INT TERM
                verifyExecution "1" "Script already running. $lockFile exists"
                sendAlert
                rm -f "$errorFile"
                exit 2
        else
                touch "$lockFile"
        fi
}


function installGum () {
        which dpkg &> /dev/null
        EXITSTATUS=$?
        if [ $EXITSTATUS -eq 0 ]; then
                curl -OL https://github.com/charmbracelet/gum/releases/download/v0.10.0/gum_0.10.0_amd64.deb
                dpkg -i gum_0.10.0_amd64.deb
                logInfo "[OK] Installed 'gum' bin"
                return 0
        fi

        which rpm &> /dev/null
        EXITSTATUS=$?
        if [ $EXITSTATUS -eq 0 ]; then
                curl -OL https://github.com/charmbracelet/gum/releases/download/v0.10.0/gum-0.10.0.x86_64.rpm
                sudo rpm -i gum-0.10.0.x86_64.rpm
                return 0
        fi
}


function verifyGum () {
        which gum &> /dev/null
        EXITSTATUS=$?
        #verifyExecution "$EXITSTATUS" "Cannot find gum tool" false

    if [ $EXITSTATUS -eq 0 ]; then
                logInfo "[OK] Found 'gum' bin"
                return 0
        fi

        installGum
}


function installPMM () {
        curl -L https://www.percona.com/get/pmm | /bin/bash
}

function pmmheader () {

        echo '{{ Bold "Percona" }} {{ Italic "Labs" }} {{ Color "99" "0" " PMM CLI " }}' | gum format --theme=light -t template

        I=$(gum style --padding "1 5" --border rounded --border-foreground 212 "PERCONA")
        LOVE=$(gum style --padding "1 4" --border thick --border-foreground 57 "LABS")
        BUBBLE=$(gum style --padding "1 8" --border normal --border-foreground 255 "PMM")
        GUM=$(gum style --padding "1 5" --border double --border-foreground 240 "CLI")

        I_LOVE=$(gum join "$I" "$LOVE")
        BUBBLE_GUM=$(gum join "$BUBBLE" "$GUM")
        gum join --align center --vertical "$I_LOVE" "$BUBBLE_GUM"

}

function getVersion () {
        USER=$1
        PASS=$2
        URL=$3
        VERVAL=$(curl -s -k -X 'GET'   "https://${USER}:${PASS}@${URL}/v1/version"   -H 'accept: application/json' | jq '.version' | awk -F. '{print $2}')

}

setLockFile
verifyGum
pmmheader

ACTION=$(gum choose "Install PMM" "Set a PMM replica" "Set a PMM Primary" Exit --cursor "> " --ordered --header="What would you like to do?" --cursor.foreground 99 --selected.foreground 99 --limit=1)
gum confirm "Confirms: $ACTION"
CONFIRMED=$?

if [ $CONFIRMED -eq 0 ]; then
        if [[ $ACTION == "Install PMM" ]]; then
                installPMM
        fi

        if [[ $ACTION == "Set a PMM replica" ]]; then
                clear
                echo "# PMM Replica" | gum format
                echo "# Using VictoriaMetrics Federation" | gum format
                echo ":candy:" | gum format -t emoji
                PRIMARY=$(gum input --header="Host / IP of the Primary PMM server" --placeholder "192.168.1.10" --prompt.foreground="99" --cursor.foreground="99" --header.foreground="240")
                PORT="443"
                USER=$(gum input --header="Primary PMM USER" --value "admin" --placeholder "admin")
                PASS=$(gum input --password  --header="Primary PMM PASSWORD")
                SCHEME="https"

        clear
                getVersion $USER $PASS $PRIMARY
                echo '{{ Bold "A new scrap will be added" }}' | gum format -t template
                # cat $scrapeyaml | gum format -t code -l yaml
                export jobname=$JOBNAME
                export scheme=$SCHEME
                export user=$USER
                export pass=$PASS
                export host=$PRIMARY
                export port=$PORT
                envsubst < $scrapeyaml > /tmp/pepe


                echo '{{ Bold "Creating: File with pmmserver IP/Host" }}' | gum format -t template
                echo $PRIMARY > /tmp/pmmserver.txt
                sudo docker cp -q /tmp/pmmserver.txt pmm-server:/srv/pmmserver.txt

                echo '{{ Bold "Creating: Replica table on ClickHouse" }}' | gum format -t template
                sudo docker cp -q metrics.sql pmm-server:/tmp/metrics.sql
                sudo docker exec pmm-server chown pmm:pmm /tmp/metrics.sql
                sudo docker exec pmm-server bash -c "clickhouse-client < /tmp/metrics.sql"


                echo '{{ Bold "Creating: Scraper YAML file" }}' | gum format -t template
                sudo docker cp -q /tmp/pepe pmm-server:/srv/prometheus/prometheus.base.yml
                sudo docker exec pmm-server chown pmm:pmm /srv/prometheus/prometheus.base.yml

                echo '{{ Bold "Creating: QAN and Inventory replica scripts" }}' | gum format -t template
                sudo docker cp -q qanreplica.sh pmm-server:/srv/qanreplica.sh
                sudo docker exec pmm-server chmod +x /srv/qanreplica.sh
                sudo docker cp -q inventoryreplica.sh pmm-server:/srv/inventoryreplica.sh
                sudo docker exec pmm-server chmod +x /srv/inventoryreplica.sh


                echo '{{ Bold "Creating: QAN and Inventory supervisord ini files" }}' | gum format -t template
                sudo docker cp -q qanreplica.ini pmm-server:/etc/supervisord.d/qanreplica.ini
                sudo docker cp -q inventoryreplica.ini pmm-server:/etc/supervisord.d/inventoryreplica.ini

                if [ $VERVAL -lt 40  ]; then
                        echo '{{ Bold "Creating: SQLite replica scripts" }}' | gum format -t template
                        sudo docker cp -q restoresqlitepmm.sh pmm-server:/srv/restoresqlitepmm.sh
                        sudo docker exec pmm-server chmod +x /srv/restoresqlitepmm.sh
                        sudo docker cp -q restoresqlitedash.sh pmm-server:/srv/restoresqlitedash.sh
                        sudo docker exec pmm-server chmod +x /srv/restoresqlitedash.sh

                        echo '{{ Bold "Creating: SQLite supervisord ini files" }}' | gum format -t template
                        sudo docker cp -q restoresqlitepmm.ini pmm-server:/etc/supervisord.d/restoresqlitepmm.ini
                        sudo docker cp -q restoresqlitedash.ini pmm-server:/etc/supervisord.d/restoresqlitedash.ini

                fi

                gum spin --show-output --spinner monkey --title "Loading..." --title.foreground 99 -- sh -c 'sudo docker exec -d pmm-server supervisorctl restart pmm-agent &> /dev/null; sleep 5; echo "PMM Metrics Replica set"'
                gum spin --show-output --spinner monkey --title "Loading..." --title.foreground 99 -- sh -c 'sudo docker exec -d pmm-server supervisorctl update &> /dev/null; sleep 5; echo "PMM QAN + Inventory Replica set"'

        fi

        if [[ $ACTION == "Set a PMM Primary" ]]; then

                VERVAL=$(docker exec pmm-server pmm-admin -v | grep PMMVersion | awk -F: '{print $2}' | awk -F. '{print $2}')
                echo $VERVAL

                echo '{{ Bold "Creating: Inventory table on ClickHouse" }}' | gum format -t template
                sudo docker cp -q pgpmm.sql pmm-server:/tmp/pgpmm.sql
                sudo docker exec pmm-server chown pmm:pmm /tmp/pgpmm.sql
                sudo docker exec pmm-server bash -c "clickhouse-client < /tmp/pgpmm.sql"

                echo '{{ Bold "Creating: Inventory primary script" }}' | gum format -t template
                sudo docker cp -q pmmpgdump.sh pmm-server:/srv/pmmpgdump.sh
                sudo docker exec pmm-server chmod +x /srv/pmmpgdump.sh

                echo '{{ Bold "Creating: Inventory supervisord ini files" }}' | gum format -t template
                sudo docker cp -q pmmpgdump.ini pmm-server:/etc/supervisord.d/pmmpgdump.ini

                if [ $VERVAL -lt 40  ]; then

                        echo '{{ Bold "Creating: sqlite tables on ClickHouse" }}' | gum format -t template
                        sudo docker cp -q sqlitepmm.sql pmm-server:/tmp/sqlitepmm.sql
                        sudo docker exec pmm-server chown pmm:pmm /tmp/sqlitepmm.sql
                        sudo docker exec pmm-server bash -c "clickhouse-client < /tmp/sqlitepmm.sql"

                        sudo docker cp -q sqlitedash.sql pmm-server:/tmp/sqlitedash.sql
                        sudo docker exec pmm-server chown pmm:pmm /tmp/sqlitedash.sql
                        sudo docker exec pmm-server bash -c "clickhouse-client < /tmp/sqlitedash.sql"

                        echo '{{ Bold "Creating: SQLite primary script" }}' | gum format -t template
                        sudo docker cp -q sqlitepmm.sh pmm-server:/srv/sqlitepmm.sh
                        sudo docker exec pmm-server chmod +x /srv/sqlitepmm.sh

                        sudo docker cp -q sqlitedash.sh pmm-server:/srv/sqlitedash.sh
                        sudo docker exec pmm-server chmod +x /srv/sqlitedash.sh

                        echo '{{ Bold "Creating: sqlite supervisord ini files" }}' | gum format -t template
                        sudo docker cp -q sqlitepmm.ini pmm-server:/etc/supervisord.d/sqlitepmm.ini
                        sudo docker cp -q sqlitedash.ini pmm-server:/etc/supervisord.d/sqlitedash.ini

                fi

                if [ $VERVAL -ge 40 ]; then
                        echo '{{ Bold "Creating: Grafana table on ClickHouse" }}' | gum format -t template
                        sudo docker cp -q pggrafana.sql pmm-server:/tmp/pggrafana.sql
                        sudo docker exec pmm-server chown pmm:pmm /tmp/pggrafana.sql
                        sudo docker exec pmm-server bash -c "clickhouse-client < /tmp/pggrafana.sql"

                        echo '{{ Bold "Creating: Grafana primary script" }}' | gum format -t template
                        sudo docker cp -q pmmgrafanadump.sh pmm-server:/srv/pmmgrafanadump.sh
                        sudo docker exec pmm-server chmod +x /srv/pmmgrafanadump.sh

                        echo '{{ Bold "Creating: grafana supervisord ini files" }}' | gum format -t template
                        sudo docker cp -q pmmgrafanadump.ini pmm-server:/etc/supervisord.d/pmmgrafanadump.ini

                fi

                echo '{{ Bold "Adding: ClickHouse Port Forwarding" }}' | gum format -t template
                docker ps -a --format '{{.Names}}' | grep -q socatpmm
                if [ $? -eq 1 ]; then
                        docker run --detach --restart unless-stopped --publish 9000:9000 --link pmm-server:target --name socatpmm alpine/socat tcp-listen:9000,fork,reuseaddr tcp-connect:target:9000
                fi

                gum spin --show-output --spinner monkey --title "Loading..." --title.foreground 99 -- sh -c 'sudo docker exec -d pmm-server supervisorctl update &> /dev/null; sleep 5; echo "PMM Primary Set"'

        fi
fi
