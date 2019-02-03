#!/bin/zsh
#
# start with: $0 start
#
# POC "built-in" httpd for bp-letsenc.
# start before any "renew"
#
# Requirements:
# * socat
# * zsh (replacing '(P)' with '!' in trim() schould make it work with bash)
#

script_dir="$(dirname $(readlink -f "${0}"))"

# default
acmedir="/srv/acme-challenges/"

# read configuration from config.zsh if readable
if [[ -r "${script_dir}/config.zsh" ]]; then
	source "${script_dir}/config.zsh"
fi

function error404() {
	printf "HTTP/1.1 404 Not Found\nContent-Length: 0\n\n"
	exit 0
}

function trim() {
	read -rd '' $1 <<<"${(P)1}"
}

function do_reply(){
	request="$(head -1)"
	method="${request%% *}"
	url="${request#* }"
	url="${url/ HTTP\/*/}"
	trim url

	# debug:
	#printf "Request for '%s' using '%s'\n" "$url" "$method" >&2

	if [[ $method != "GET" ]]; then
		error404 # this "server" only answers to GET requests
	elif [[ ! $url =~ ^/.well-known/acme-challenge/.* ]]; then
		error404 # this server only answers to acme challenges
	else
		file="${url#\/.well-known\/acme-challenge\/}"
		#printf "Parsed filename: '%s'\n" "$file" >&2
		if ! [[ -r "${acmedir}/${file}" ]]; then
			error404
		fi

		size="$(stat --format '%s' "${acmedir}/${file}")"

		# http headers
		printf "HTTP/1.1 200 OK\n"
		printf "Server: poc-httpd.zsh\n"
		printf "Content-Type: text/plain\n"
		if [[ -n "$size" ]]; then
			printf "Content-Length: %s\n" "$size"
		fi
		printf "\n"

		# http body
	  cat "${acmedir}/${file}"
	fi

}

# main

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
		printf "Usage: $0 (start|stop|reply)\n"
		printf "  reply  for internal use\n"
		printf "  start  starts socat listening to port 80 and calling $0 reply for every request\n"
		printf "  stop   kills the started socat\n\n"
		;;
esac
