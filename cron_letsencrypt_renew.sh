#!/bin/zsh

## Copyright (c) 2017-2019 brainpower <brainpower at mailbox dot org>
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

script_dir="$(dirname $(readlink -f "${0}"))"

# directory containing the certificate subdirectories
xbasedir="/var/local/letse/"
logfile="${xbasedir}/renew.log"

# renew X days prior to expiry of crt
renew_before=20
warn_before=7

warn_mail=""
warn_message="Certificate %s on %s has only %d valid days left.\nRenew seems to have failed repeatedly. Please check.\n"
renew_message="\n[$(date "+%F %T")] %s: %s (valid days left: %d)\n"

# do dry run?
dry=0

# read configuration from config.zsh if readable
if [[ -r "${script_dir}/config.zsh" ]]; then
  source "${script_dir}/config.zsh"
fi

if [[ "$1" == "-n" ]]; then
  dry=1
fi


for cert in $(cat "${xbasedir}"/active); do

  expiresAt="$(date -d "$(openssl x509 -in "${xbasedir}/${cert}/live/certificate.crt" -noout -enddate | sed s/notAfter=//g)" +%s)"
  now="$(date +%s)"

  diff=$(( expiresAt - now  ))
  diffdays=$(( diff / 86400 ))

  if [[ -n "$warn_mail" ]]; then
    if [[ $diffdays -le $warn_before ]]; then
      if [[ $dry -gt 0 ]]; then
        printf "$warn_message" "$cert" "$(hostname --fqdn)" "$diffdays"
      else
        printf "$warn_message" "$cert" "$(hostname --fqdn)" "$diffdays" \
          | mail -s "LE-RENEW: Problem with ${cert}" "$warn_mail"
      fi
    fi
  fi

  if [[ $diffdays -le $renew_before ]]; then
    if [[ "$dry" -gt 0 ]]; then

      printf "$renew_message" "DRY RUN" "$cert" "$diffdays" >> "${logfile}"

      printf "DRY RUN: Would renew %s (valid days left: %d)\n" "$cert" "$diffdays"

    else

      printf "$renew_message" "RENEW" "$cert" "$diffdays" >> "${logfile}"

      "${script_dir}"/bp-lets.zsh renew "$cert"

    fi
  fi
done
