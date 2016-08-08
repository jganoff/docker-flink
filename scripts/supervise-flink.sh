#!/usr/bin/env bash

case "$FLINK_MANAGER_TYPE" in
    "t"|"task"|"taskmanager")
        CONFIG="supervisor-taskmanager.ini"
    ;;
    "j"|"job"|"jobmanager")
        CONFIG="supervisor-jobmanager.ini"
    ;;
    *)
        echo "Invalid FLINK_MANAGER_TYPE: '$FLINK_MANAGER_TYPE'"
        echo "Choose one of 'task' or 'job'"
        exit 55
    ;;
esac

# Execute supervisord instead of calling it directly so the current process
# (the shell running this script) is replaced by supervisord and it receives
# all signals directly from Docker.
exec supervisord -n -c "/etc/supervisor.d/$CONFIG"

