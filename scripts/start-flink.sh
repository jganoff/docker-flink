#!/usr/bin/env bash

TYPE="$1"

CONF="$FLINK_HOME/conf/flink-conf.yaml"
EXEC="$FLINK_HOME/bin/${TYPE}.sh"

function edit_properties() {
  local RAW_KEY="$1"
  local RAW_VALUE="$2"

  if [ -z "$RAW_KEY" ]; then
      return 1
  fi
  if [ -z "$RAW_VALUE" ]; then
      return 2
  fi

  # sanitize for grep/sed pattern
  local KEY=$(echo "$RAW_KEY" | sed 's/[]\/$*.^|[]/\\&/g')
  local VALUE=$(echo "$RAW_VALUE" | sed 's/[]\/$*.^|[]/\\&/g')

  # replace if found, append if not
  grep "^\\s*\($KEY\)" "$CONF" > /dev/null \
    && sed -i "s/^\\s*\($KEY\)\\s*:\(.*\)$/\1: $VALUE/" "$FILE" \
    || echo "$RAW_KEY: $RAW_VALUE" >> "$FILE"
}

edit_properties 'jobmanager.heap.mb' '256'
edit_properties 'taskmanager.heap.mb' '512'
edit_properties 'taskmanager.numberOfTaskSlots' '4'
edit_properties 'taskmanager.memory.preallocate' 'false'
edit_properties 'parallelism.default' '1'
edit_properties 'taskmanager.tmp.dirs' '/tmp/flink'
edit_properties 'env.pid.dir' '/var/run'
edit_properties 'jobmanager.web.history' '20'

case "$TYPE" in
  "jobmanager" )
    echo "Starting Flink Job Manager"
    edit_properties 'jobmanager.rpc.address' "${HOSTNAME:-localhost}"
    edit_properties 'jobmanager.rpc.port' '6123'
  ;;
  "taskmanager" )
    echo "Starting Flink Task Manager"
    # port + address env vars come from docker links
    edit_properties 'jobmanager.rpc.address' "${FLINK_JOBMANAGER_PORT_6123_TCP_ADDR:-flinkjobmanager}"
    edit_properties 'jobmanager.rpc.port' "${FLINK_JOBMANAGER_PORT_6123_TCP_PORT:-6123}"
  ;;
  * )
    echo "Invalid type: $TYPE, exiting!"
    exit 1001
  ;;
esac

echo "Configuring Job Manager on this node:"
cat "$CONF"

CMD="${EXEC} start cluster"
echo "${CMD}"

trap "${EXEC} stop cluster;exit 0" SIGINT SIGTERM 15 9 10
${CMD}

sleep 1

# now make this thing run in the foreground
tail -s 5 -F "$FLINK_HOME/log/flink-*.log"
