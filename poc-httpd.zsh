#!/bin/zsh
#
# start with: $0 start
#
# POC "built-in" httpd for bp-letsenc.
# start before any "renew"
#

script_dir="$(dirname $(readlink -f "${0}"))"

# default
acmedir="/srv/acme-challenges/"

# read configuration from config.zsh if readable
if [[ -r "${script_dir}/config.zsh" ]]; then
	source "${script_dir}/config.zsh"
fi


case $1 in
	reply)
		do_reply
		;;
	start)
		if ! [[ -r "${pidfile}" ]]; then
			socat TCP-LISTEN:80,crlf,reuseaddr,fork SYSTEM:"$0 reply" &
			printf "%s" "$!" > ${pidfile}
		else
			echo "Pidfile exists. Already started?"
			exit 1
		fi
		;;
	stop)
		kill -15 "$(cat ${pidfile})"
		rm -rf "${pidfile}"
		;;
	*)
		printf "Usage: $0 (start|stop|listen)\n"
		printf "  reply  for internal use\n"
		printf "  start  starts socat listening to port 80 and calling $0 listen for every request\n"
		printf "  stop   kills the started socat\n\n"
		;;
esac




function error404() {
	printf "HTTP/1.1 404 Not Found\nContent-Length: 0\n"
	exit 0
}

function do_reply(){
	file="$(head -1 | sed 's@GET /.well-known/acme-challenge/\(.*\) HTTP.*@\1@')"

	if printf "%s\n" "$file" | grep -q '^GET'; then
		error404
	else
		if ! [[ -r "${acmedir}/${file}" ]]; then
			error404
		fi

		size="$(stat --format '%s' "/${file}")"

		# http headers
		printf "HTTP/1.1 200 Not Found\n"
		printf "Content-Type: text/plain\n"
		if [[ -n "$size" ]]; then
			printf "Content-Length: %s\n" "$size"
		fi
		printf "\n"

		# http body
	  cat "${acmedir}/${file}"
	fi

}
