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
    ZAPRET2_INIT="/opt/zapret2/init.d/sysv/zapret2"
    if [ -f "/opt/zapret2/init.d/openwrt/zapret2" ]; then
      ZAPRET2_INIT="/opt/zapret2/init.d/openwrt/zapret2"
    fi
    "$ZAPRET2_INIT" restart
    wan_logger "Zapret restarted"
fi
