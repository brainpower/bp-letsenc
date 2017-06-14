#!/bin/zsh

basedir="${HOME}/letse/"

# renew X days prior to expiry of crt
renew_before=20

script_dir="$(dirname $(readlink -f "${0}"))"

for cert in $(cat "${basedir}"/active); do
	expiresAt="$(date -d "$(openssl x509 -in "${basedir}/${cert}/live/certificate.crt" -noout -enddate | sed s/notAfter=//g)" +%s)"
	now="$(date +%s)"

	diff=$(( expiresAt - now  ))
	diffdays=$(( diff / 86400 ))

	if [[ $diffdays -le $renew_before ]]; then
		"${script_dir}"/letsencrypt.zsh renew "$cert"
	fi
done
