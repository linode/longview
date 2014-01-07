#!/bin/bash

SUCCESS="\E[32;40mSuccess\E[0m"
FAILED="\E[31;40mFailed\E[0m"

LV="/opt/linode/longview/Linode/Longview.pl"

case "$1" in
	start)
		echo -n $"Starting longview: "
		$LV
		RET=$?
		[ $RET -eq 0 ] && echo -e $SUCCESS || echo -e $FAILED
		exit $RET
	;;
	debug)
		echo -n $"Starting longview (With Debug Flag): "
		$LV Debug
		RET=$?
		[ $RET -eq 0 ] && echo -e $SUCCESS || echo -e $FAILED
		exit $RET
	;;
	stop)
		echo -n $"Stopping longview: "
		kill `cat /var/run/longview.pid` 2>/dev/null
		RET=$?
		[ $RET -eq 0 ] && echo -e $SUCCESS || echo -e $FAILED
		exit $RET
	;;
	restart)
		$0 stop
		$0 start
	;;
	status)
		[ ! -e /var/run/longview.pid ] && echo "No longview pid file: status unknown" && exit 1
		PID=`cat /var/run/longview.pid`
		grep "linode-longview" "/proc/$PID/cmdline" 2>/dev/null
		RET=$?
		[ $RET -eq 0 ] && echo "Longview is running" || echo "Longview is not running"
		exit $RET
	;;
	*)
		echo $"Usage: $0 {start|stop|restart|status}"
	;;
esac