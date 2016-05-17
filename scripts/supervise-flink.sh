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

supervisord -n -c "/etc/supervisor.d/$CONFIG"
