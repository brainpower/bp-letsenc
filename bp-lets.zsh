#!/bin/zsh

## Copyright (c) 2017-2018 brainpower <brainpower at mailbox dot org>
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
## THE SOFTWARE.

if [[ $1 =~ "help" ]] || { [[ -z "$2" ]] && [[ $1 != "create-account"  ]] } || [[ -z "$1" ]]; then
	printf "Usage: \n" >&2
	printf "   %s create-account\n" "$0" >&2
	printf "   %s create-certificate <certname>\n" "$0" >&2
	printf "   %s help\n" "$0" >&2
	printf "   %s renew              <certname>\n" "$0" >&2
	printf "\n" >&2
	printf "Actions:\n" >&2
	printf "   create-account  Generates the Let's Encrypt account key.\n" >&2
	printf "   create-cert     Generates a private key and a CSR for a certificate. <certname> should be an unique identifier for the certificate.\n" >&2
	printf "   help            Show this help.\n" >&2
	printf "   renew           Request a new or renew an old certificate using acme-tiny.\n" >&2
	exit 1
fi
action="$1"
certname="$2"
script_dir="$(dirname $(readlink -f "${0}"))"


# set a variable if it is unset or empty
# $1: name of the variable
# $2: value to be set
function set_if_unset() {
	if [[ -z "${(P)1}" ]]; then
		eval "${1}=${2}"
	fi
}

#################################
#  BEGIN default configuration  #
#################################

# DEPRECATED: use a post-renew.d/ script
# services to be reloaded after renewal
services=()

if [[ -r "${script_dir}/config.zsh" ]]; then
	source "${script_dir}/config.zsh"
fi

# permissions to be set on the directory containing key and certificate
set_if_unset dirmode "750"

# directory served at http://<domain>/.well-known/acme-challenge/
set_if_unset acmedir "/srv/acme-challenges/"

# location of the acme-tiny python script
set_if_unset acmebin "${HOME}/acme-tiny/acme_tiny.py"

# directory containing the certificate subdirectories
set_if_unset xbasedir "${HOME}/letse"

# absolute path of the certificate subdirectory
set_if_unset basedir "${xbasedir}/${certname}"

# absolute directory to place the new certificate in,
# $livedir will be symlinked to this directory if renewal is successful
set_if_unset newdir "${basedir}/$(date +%F)"

# path of the symlink to $newdir
set_if_unset livedir "${basedir}/live"

# path to the Let's Encrypt account key
set_if_unset acckey "${xbasedir}/account.key"

# size of the account key in bits (only used by "create-account" action)
set_if_unset acckeysize 4096

# size of the certificate's private key (only used by "create-certificate")
set_if_unset keysize 4096

# the location of the openssl.cnf used for adding SANs to the csr
set_if_unset openssl_cnf "/etc/ssl/openssl.cnf"


###############################
#  END default configuration  #
###############################


# check if given files are readable, error out otherwise
# $@: list of files
function check_files_readable() {
  local file
  for file in "$@"; do
    if [[ ! -r "$file" ]]; then
      printf "ERROR: Required file %s is missing or not readable!" "$file" >&2
      exit 1
    fi
  done
}


# execute scripts in post-renew.d if any exist
# $@: a list of dirs with a post-renew.d folder with scripts in them
function exec_post_renew_d(){
	for dir in "$@"; do
		if [[ -d "${dir}/post-renew.d/" ]]; then
			find "${dir}/post-renew.d/" -type f -print0 | while read -d $'\0' dfile; do
				if [[ -x "$dfile" ]]; then
					"$dfile" "${basedir}/live/" "$certname"
				fi
			done
		fi
	done
}


# split a certificate bundle into the certificate and the intermediates.
# output files will be completely overwritten!
# $1: the source file, cert + intermediates as pem
# $2: the name of the file to write the certificate to
# $3: the name of the file to write the intermediates to
function split_cert(){
  printf "" > "$2"
  printf "" > "$3"
  awk '
    BEGIN { n=0; p=0 }
    /-----BEGIN CERTIFICATE-----/ { n++; p=1 }
    {
      if ( p > 0 ){
        if( n == 1 ) {
          print > "'"$2"'"
        } else {
          print >> "'"$3"'"
        }
      }
    }
    /-----END CERTIFICATE-----/ { p=0 }
  ' < "$1"
}


##########
#  main  #
##########

if [[ $action = "renew" ]]; then
	if [[ ! -d "$basedir" ]]; then
		printf "ERROR: %s does not exist!\n" "$basedir" >&2
		printf "Unable to renew non-existent certificate!\n" >&2
		exit 1
	fi

	check_files_readable \
	  "${basedir}/private.key" \
	  "${basedir}/request.csr"

	mkdir -p "${newdir}"
	chmod "${dirmode}" "${newdir}"
	cd "${newdir}"

	python "${acmebin}" \
	  --account-key "${acckey}" \
	  --acme-dir "${acmedir}" \
	  --csr "${basedir}/request.csr" \
	    > "${newdir}/full-bundle.crt"

	if [[ $? == 0 ]]; then

    split_cert "${newdir}/full-bundle.crt" \
      "${newdir}/certificate.crt" \
      "${newdir}/ca-bundle.crt"

		cp -a "${basedir}/private.key" "${newdir}/private.key"
		cat   "${newdir}/private.key"  "${newdir}/full-bundle.crt" > "${newdir}/key-bundle.crt"

		cd "${basedir}"
		ln -Tfs "${newdir}" live

		if [[ -n "${services}" ]]; then
		  printf "WARNING: Using the services array is deprecated, use a post-renew.d script instead.\n" >&2
			sudo systemctl reload "${services[@]}"
		fi
		exec_post_renew_d "${script_dir}" "${basedir}"
	fi


elif [[ $action = "create-account" ]]; then
	if [[ -f $acckey ]]; then
		printf "ERROR: Account Key already exists: %s\n" "$acckey" >&2
		printf "If you really want to create a new one, delete it first!\n" >&2
		exit 1
	fi

	mkdir -p "${xbasedir}"
	chmod "${dirmode}" "${xbasedir}"
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
	chmod "${dirmode}" "${basedir}"
	cd "${basedir}" || exit 1

	subject="/CN=${domains[1]}"
	cp "${openssl_cnf}" openssl.cnf
	printf "[SAN]\nsubjectAltName=" >> openssl.cnf
	for dom in "${domains[@]}"; do
		printf "DNS:%s," "$dom" >> openssl.cnf
	done
	printf "\n" >> openssl.cnf
	sed '/subjectAltName/s@,$@@' -i openssl.cnf


	printf "Generating new private key...\n"
	openssl genrsa "$keysize" > "private.key"

	printf "Generating new CSR...\n"
	openssl req -new -sha256 -key "private.key" -subj "${subject}" -reqexts SAN -config openssl.cnf > request.csr

	printf "Use '%s renew %s' now to request the new certificate..." "$0" "${certname}"

	printf "%s\n" "${certname}" >> "${xbasedir}/active"

fi
