#!/bin/bash
set -euxo pipefail

if [[ -z "$NGINX_LE_DOMAINS" ]] ; then
    echo "nginx-le requires at least one FQDN to manage (NGINX_LE_DOMAINS)"
    exit 1
fi

if [[ -z "$NGINX_LE_EMAIL" ]] ; then
    echo "nginx-le requires a email address (NGINX_LE_EMAIL)"
    exit 1
fi

IFS=',' read -r -a DOMAINS_ARRAY <<< "$NGINX_LE_DOMAINS"

LE_DIR="/etc/letsencrypt"
LE_LIVE_DIR="${LE_DIR}/live/${DOMAINS_ARRAY[0]}"

FULLCHAIN_PATH="${LE_LIVE_DIR}/fullchain.pem"
PRIVKEY_PATH="${LE_LIVE_DIR}/privkey.pem"
DHPARAM_PATH='/etc/letsencrypt/dhparam.pem'

# generate dhparams if they don't exist
if ! [[ -f "$DHPARAM_PATH" ]] ; then
    openssl dhparam -out "$DHPARAM_PATH" 2048
fi

# if the fullchain or the privkey does not exist, generate some mock certificates
if [[ ! -f "$FULLCHAIN_PATH" || ! -f "$PRIVKEY_PATH" ]] ; then
    set +e
    rm -f "$FULLCHAIN_PATH"
    rm -f "$PRIVKEY_PATH"
    set -e

    mkdir -p "$LE_LIVE_DIR"
    
    (
	echo DE
	echo FooState
	echo BarCity
	echo FoobarCompany
	echo BuzzOU
	echo "${DOMAINS_ARRAY[0]}"
	echo
    ) | openssl req -x509 -nodes -days 1 -newkey rsa:2048 -keyout "$PRIVKEY_PATH" -out "$FULLCHAIN_PATH"
fi

nginx -g 'daemon off;' &
NGINX_PID=$!

echo 'waiting for nginx to open the keys'
sleep 5s

function cleanLeDirs() {
    echo "cleaning all let's encrypt directories"
    find "$LE_DIR" -mindepth 1 -type d -exec rm -rf {} +
}

(while [[ -z "${NGINX_LE_DISABLE:-}" ]] ; do
     if openssl x509 -noout -text -in "$FULLCHAIN_PATH" | grep FoobarCompany ; then
	 echo "deleting self signed certificates in 'live' directory"
	 cleanLeDirs
     fi

     if [[ -z "${NGINX_LE_TEST_CERT:-}" ]] && openssl x509 -noout -text -in "$FULLCHAIN_PATH" | grep 'Fake LE'; then
	 echo "a non testing certificate was requested, but testing certificate still exists. removing..."
	 cleanLeDirs
     fi
     
     if ! certbot certonly --webroot --noninteractive --renew-with-new-domains --expand ${NGINX_LE_TEST_CERT:+--test-cert} --agree-tos -m "$NGINX_LE_EMAIL" -d "$NGINX_LE_DOMAINS" --webroot-path /app/le-challenge ; then
	 echo "error while renewing certificates with certbot"
     else
	 echo "reloading nginx..."
	 nginx -s reload
     fi

     echo "sleeping for 24h..."
     sleep 24h
 done) &
LOOP_PID=$!

wait $NGINX_PID
kill $LOOP_PID
