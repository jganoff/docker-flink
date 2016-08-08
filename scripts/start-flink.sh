#!/usr/bin/env bash

TYPE="$1"

FLINK_JOBMANAGER_RPC_ADDRESS=${FLINK_JOBMANAGER_RPC_ADDRESS:-localhost}
FLINK_JOBMANAGER_RPC_PORT=${FLINK_JOBMANAGER_RPC_PORT:-6123}
FLINK_HEAP_MB=${FLINK_HEAP_MB:-256}
FLINK_NUM_TASK_SLOTS=${FLINK_NUM_TASK_SLOTS:-1}
FLINK_TMP_DIRS=${FLINK_TMP_DIRS:-/tmp/flink}
FLINK_JOBMANAGER_WEB_HISTORY=${FLINK_JOBMANAGER_WEB_HISTORY:-20}

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
    && sed -i "s/^\\s*\($KEY\)\\s*:\(.*\)$/\1: $VALUE/" "$CONF" \
    || echo "$RAW_KEY: $RAW_VALUE" >> "$CONF"
}

edit_properties 'jobmanager.heap.mb' $FLINK_HEAP_MB
edit_properties 'taskmanager.heap.mb' $FLINK_HEAP_MB
edit_properties 'taskmanager.numberOfTaskSlots' $FLINK_NUM_TASK_SLOTS
edit_properties 'taskmanager.memory.preallocate' 'false'
edit_properties 'parallelism.default' '1'
edit_properties 'taskmanager.tmp.dirs' $FLINK_TMP_DIRS
edit_properties 'env.pid.dir' '/var/run'
edit_properties 'jobmanager.web.history' $FLINK_JOBMANAGER_WEB_HISTORY
edit_properties 'jobmanager.rpc.address' $FLINK_JOBMANAGER_RPC_ADDRESS
edit_properties 'jobmanager.rpc.port' $FLINK_JOBMANAGER_RPC_PORT

case "$TYPE" in
  "jobmanager" )
    echo "Starting Flink Job Manager"
    PID_FILE=/var/run/flink--jobmanager.pid
  ;;
  "taskmanager" )
    echo "Starting Flink Task Manager"
    PID_FILE=/var/run/flink--taskmanager.pid
  ;;
  * )
    echo "Invalid type: $TYPE, exiting!"
    exit 1001
  ;;
esac

CMD="${EXEC} start cluster"
echo "${CMD}"

trap "${EXEC} stop cluster; exit 1" SIGINT SIGTERM 15 9 10
${CMD}

# Sleep long enough to let Flink create the log files
while [ ! -f $FLINK_HOME/log/flink-*.log ]; do
  sleep 1
done

# Pipe Flink output to stdout
tail -10000 -f $FLINK_HOME/log/flink-*.log &
tail -10000 -f $FLINK_HOME/log/flink-*.out &

# Wait for Flink process to terminate...
PID=$(cat $PID_FILE)
while [[ ( -d /proc/$PID ) && ( -z $(grep zombie /proc/$PID/status) ) ]]; do
    sleep 1
done

