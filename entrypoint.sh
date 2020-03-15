#!/bin/bash

# fix docker socket perms
if [ -S "/var/run/docker.sock" ]; then
       SOCK_GID="$(stat -c "%g" /var/run/docker.sock)"
       CURR_GID="$(getent group docker|cut -d: -f3)"
       if [ "$SOCK_GID" != "$CURR_GID" ]; then
               echo "fixing docker gid"
               groupmod -g "${SOCK_GID}" docker
       fi
fi

init(){
	local pcscd_running
	pcscd_running=$(pgrep pcscd)
	if [ -z "$pcscd_running" ]; then
		echo "starting pcscd in backgroud"
		pcscd --debug --apdu
		pcscd --hotplug
	else
		echo "pcscd is running in already: ${pcscd_running}"
	fi
}

init

HOSTNAME="$(hostname)"
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts

exec "$@"
