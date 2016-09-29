#!/usr/bin/env bash

TYPE="$1"

FLINK_JOBMANAGER_RPC_ADDRESS=${FLINK_JOBMANAGER_RPC_ADDRESS:-localhost}
FLINK_JOBMANAGER_RPC_PORT=${FLINK_JOBMANAGER_RPC_PORT:-6123}
FLINK_HEAP_MB=${FLINK_HEAP_MB:-256}
FLINK_NUM_TASK_SLOTS=${FLINK_NUM_TASK_SLOTS:-1}
FLINK_TMP_DIRS=${FLINK_TMP_DIRS:-/tmp/flink}
FLINK_JOBMANAGER_WEB_HISTORY=${FLINK_JOBMANAGER_WEB_HISTORY:-20}
FLINK_STATE_BACKEND=${FLINK_STATE_BACKEND:-jobmanager}
FLINK_STATE_BACKEND_FS_CHECKPOINTDIR=${FLINK_STATE_BACKEND_FS_CHECKPOINTDIR:-file:///flink/checkpoints}
FLINK_SAVEPOINTS_STATE_BACKEND=${FLINK_SAVEPOINTS_STATE_BACKEND:-jobmanager}
FLINK_SAVEPOINTS_STATE_BACKEND_FS_DIR=${FLINK_SAVEPOINTS_STATE_BACKEND_FS_DIR:-file:///flink/savepoints}
FLINK_HA=${FLINK_HA:-standalone}
FLINK_HA_ZK_PATH_ROOT=${FLINK_HA_ZK_PATH_ROOT:-/flink}
FLINK_HA_ZK_PATH_NAMESPACE=${FLINK_HA_ZK_PATH_NAMESPACE:-/default_ns}
FLINK_HA_ZK_CLIENT_SESSION_TIMEOUT=${FLINK_HA_ZK_CLIENT_SESSION_TIMEOUT:-60000}
FLINK_HA_ZK_CLIENT_CONNECTION_TIMEOUT=${FLINK_HA_ZK_CLIENT_CONNECTION_TIMEOUT:-15000}
FLINK_HA_ZK_CLIENT_RETRY_WAIT=${FLINK_HA_ZK_CLIENT_RETRY_WAIT:-3}
FLINK_HA_JOB_DELAY=${FLINK_HA_JOB_DELAY:-10s}

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
# Use the same port for HA as we do for standalone.
edit_properties 'recovery.jobmanager.port' $FLINK_JOBMANAGER_RPC_PORT
edit_properties 'state.backend' $FLINK_STATE_BACKEND
edit_properties 'state.backend.fs.checkpointdir' $FLINK_STATE_BACKEND_FS_CHECKPOINTDIR
edit_properties 'savepoints.state.backend' $FLINK_SAVEPOINTS_STATE_BACKEND
edit_properties 'savepoints.state.backend.fs.dir' $FLINK_SAVEPOINTS_STATE_BACKEND_FS_DIR
edit_properties 'recovery.mode' $FLINK_HA
edit_properties 'recovery.zookeeper.quorum' $FLINK_HA_ZK_QUORUM
edit_properties 'recovery.zookeeper.path.root' $FLINK_HA_ZK_PATH_ROOT
edit_properties 'recovery.zookeeper.path.namespace' $FLINK_HA_ZK_PATH_NAMESPACE
edit_properties 'recovery.zookeeper.storageDir' $FLINK_HA_ZK_STORAGE_DIR
edit_properties 'recovery.zookeeper.client.session-timeout' $FLINK_HA_ZK_CLIENT_SESSION_TIMEOUT
edit_properties 'recovery.zookeeper.client.connection-timeout' $FLINK_HA_ZK_CLIENT_CONNECTION_TIMEOUT
edit_properties 'recovery.zookeeper.client.retry-wait' $FLINK_HA_ZK_CLIENT_RETRY_WAIT
edit_properties 'recovery.zookeeper.client.max-retry-attempts' $FLINK_HA_ZK_CLIENT_MAX_RETRY_ATTEMPTS
edit_properties 'recovery.job.delay' $FLINK_HA_JOB_DELAY

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

