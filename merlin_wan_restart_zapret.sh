#!/bin/sh

wan_logger(){
    echo "WAN Zapret: $@"|/usr/bin/logger -s
}
WAN_STATE=$2
if [ $WAN_STATE = "connected" ]
then
    wan_logger "Waiting 5000ms after connected"
    sleep 5
    wan_logger "Restarting zapret"
    /opt/zapret/init.d/sysv/zapret restart
    wan_logger "Zapret restarted"
fi
