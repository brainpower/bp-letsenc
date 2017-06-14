#!/bin/zsh

if { [[ -z "$2" ]] && [[ $1 != "create-account"  ]] } || [[ -z "$1" ]]; then
	printf "Usage: %s <action> <certname>\n" "$0" >&2
	exit 1
fi
action="$1"

services=(httpd dovecot postfix)

acmedir="/srv/acme-challenges/"
acmebin="${HOME}/acme-tiny/acme_tiny.py"

openssl_cnf="/etc/ssl/openssl.cnf"

xbasedir="${HOME}/letse"
basedir="${xbasedir}/$2"
newdir="${basedir}/$(date +%F)"
livedir="${basedir}/live"

acckey="${xbasedir}/account.key"
acckeysize=4096
keysize=4096


if [[ $action = "renew" ]]; then
	if [[ ! -d "$basedir" ]]; then
		printf "ERROR: %s does not exist!\n" "$basedir" >&2
		printf "Unable to renew non-existent certificate!\n" >&2
		exit 1
	fi

	mkdir -p "${newdir}"
	cd "${newdir}"

	python "${acmebin}" --account-key "${acckey}" --acme-dir "${acmedir}" --csr "${basedir}/request.csr" > certificate.crt

	if [[ $? == 0 ]]; then

		cp -ar "${basedir}/private.key"      "${newdir}/private.key"
		cp -ar "${basedir}/intermediate.pem" "${newdir}/ca-bundle.crt"
		cat    "${newdir}/certificate.crt"   "${newdir}/ca-bundle.crt" > "${newdir}/full-bundle.crt"
		cat    "${newdir}/private.key"       "${newdir}/certificate.crt"   "${newdir}/ca-bundle.crt" > "${newdir}/key-bundle.crt"

		cd "${basedir}"
		ln -Tfs "${newdir}" live

		sudo systemctl reload "${services[@]}"
	fi


elif [[ $action = "create-account" ]]; then
	if [[ -f $acckey ]]; then
		printf "ERROR: Account Key already exists: %s\n" "$acckey" >&2
		printf "If you really want to create a new one, delete it first!\n" >&2
		exit 1
	fi

	mkdir -p "${xbasedir}"
	openssl genrsa "$acckeysize" > "$acckey"
	if [[ $? = 0 ]]; then
		printf "Key successfully generated.\n"
	fi


elif [[ $action = "create-cert" ]]; then
	if [[ -d "$basedir" ]]; then
		printf "ERROR: %s already exists!\n" "$basedir" >&2
		printf "If you really want a new certificate, give it another name or remove the existing one.\n" >&2
		exit 1
	fi

	domains=()
	printf "Please enter all domains you want (don't forget www. !; empty string submits):\n"
	while IFS= read -r dom; do
		if [[ -z "$dom" ]]; then
			break
		fi
		domains+=( "$dom" )
	done
	printf "Entered domains are:\n"
	for dom in "${domains[@]}"; do
		printf "* '%s'\n" $dom
	done
	printf "Continue? [Yn] "
	read
	if [[ $REPLY =~ [Nn][Oo]* ]]; then
		exit 1
	fi


	mkdir -p "$basedir"
	cd "${basedir}" || exit 1

	subject="/CN=${domains[1]}"
	if [[ ${#domains[@]} -gt 1 ]]; then
		cp "${openssl_cnf}" openssl.cnf
		printf "[SAN]\nsubjectAltName=" >> openssl.cnf
		for dom in "${domains[@]}"; do
			printf "DNS:%s," "$dom" >> openssl.cnf
		done
		printf "\n" >> openssl.cnf
		sed '/subjectAltName/s@,$@@' -i openssl.cnf
	fi


	printf "Generating new private key...\n"
	openssl genrsa "$keysize" > "private.key"

	printf "Generating new CSR...\n"
	if [[ ${#domains[@]} -gt 1 ]]; then
		openssl req -new -sha256 -key "private.key" -subj "${subject}" -reqexts SAN -config openssl.cnf > request.csr
	else
		openssl req -new -sha256 -key "private.key" -subj "${subject}" > request.csr
	fi

	if [[ ! -e ../intermediate.pem ]]; then
		printf "Downloading intermediate cert...\n"
		wget https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt -O ../intermediate.pem
	fi

	printf "Linking intermediate cert...\n"
	ln -s ../intermediate.pem

	printf "Use '%s renew %s' now to request the new certificate..." "$0" "$2"

	printf "%s\n" "$2" >> "${xbasedir}/active"

fi
