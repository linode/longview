#!/bin/bash
#chkconfig: 2345 50 10
#description: Longview statistics gathering
#processname: linode-longview

LVDAEMON="/opt/linode/longview/Linode/Longview.pl"

. /etc/rc.d/init.d/functions

case "$1" in
	start)
		echo -n "Starting longview: "
		$LVDAEMON
		RET=$?
		[ $RET -eq 0 ] && success || failure
		echo
		exit $RET
	;;
	debug)
		echo -n "Starting longview (With Debug Flag): "
		$LVDAEMON Debug
		RET=$?
		[ $RET -eq 0 ] && success || failure
		echo
		exit $RET
	;;
	stop)
		echo -n "Stopping longview: "
		kill `cat /var/run/longview.pid` 2>/dev/null
		RET=$?
		[ $RET -eq 0 ] && success || failure
		[ $RET -eq 0 ] && rm /var/run/longview.pid
		echo
		exit $RET
	;;
	restart)
		$0 stop
		$0 start
	;;
	status)
		status -p /var/run/longview.pid longview
	;;
	*)
		echo $"Usage: $0 {start|stop|restart|status}"
	;;
esac