# bp-letsencrypt

a small wrapper around acme-tiny for managing certificates

acme-tiny can be found here: https://github.com/diafygi/acme-tiny

Reding acme-tiny's documentation will be helpful for understanding this script.
I *very* *strongly* recommend you to read it before using this!

## Installation

1. Clone this repository
2. Install acme-tiny somewhere on your system.
3. Open bp-lets.zsh using your favourite editor and set the variables to your liking.<br>
   See the Confuguration section for more information and don't forget to set the path to acme_tiny.py!
4. Create an account key if you haven't got one yet. (See create-account action below)

## Actions

The first argument to `bp-lets.zsh` is the action it shall perform.<br>
These actions are:

### create-account

    ./bp-lets.zsh create-account

This command generates a new account key if it does not exist.

### create-cert <certname>

    ./bp-lets.zsh create-cert ssl.example.org

This command generates a new private key and a CSR locally identified by 'ssl.example.org'.
You can choose whatever identifier you want here, it is only used by this script.
It's usually a good idea to use the certificates main domain though.<br>
The script will ask for the domains for which the certificate shall be valid.
Put each domain on a single line; an empty line will submit. The domainns will be re-printed for checking.

### renew <certname>

    ./bp-lets.zsh renew ssl.example.org

This command will request a new certificate using acme-tiny and the CSR identified by ssl.example.org,
effectively renewing the certificate, if it already exists.

Make sure `http://<domain>/.well-known/acme-challenge/` is served correctly, <br>
you've got an account key <br>
and you've created the CSR preferably using `create-cert` before calling this.

See `cron_letsencrypt_renew.sh` for an example of automatic renewing using this.


## Configuration

Configuration is done through setting the variables in the configuration block of bp-lets.zsh.
The variables and their effects are:

### acckey

The Let's Encrypt account key.<br>
When creating the key, this is the file it'll be written to.<br>
When requesting certificates, the account key will be read from this file.<br>
It is passed to acme-tiny via `--account-key`.

### acckeysize

The size in bits of the account key. Only used when generating an account key.<br>

### acmebin

The path to the acme-tiny script.<br>
Point this varibale to the location of the acme-tiny script on your machine.<br>
For example: `/usr/local/bin/acme-tiny.py`

### acmedir

The path to the callenges directory.<br>
This directory must be served at `http://<domain>/.well-known/acme-challenge/`.<br>
It is passed to acme-tiny via `--acme-dir`.

### basedir

The path where a certificate's files are stored.<br>
Default: `$xbasedir/<certname>`<br>
<certname> is the identifier of the certificate.
