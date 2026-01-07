#!/bin/sh
[ "$table" != "mangle" ] && [ "$table" != "nat" ] && exit 0
if [ -f "/opt/zapret2/init.d/openwrt/zapret2" ]; then
  ZAPRET2_INIT="/opt/zapret2/init.d/openwrt/zapret2"
elif [ -f "/opt/zapret2/init.d/sysv/zapret2" ]; then
  ZAPRET2_INIT="/opt/zapret2/init.d/sysv/zapret2"
else
  ZAPRET2_INIT="/opt/zapret2/init.d/sysv/zapret2"
fi
"$ZAPRET2_INIT" restart-fw
exit 0
