#!/usr/bin/env bash

usage_and_error() {
  echo "create_keys_and_csrs.sh [NAME] [EMAIL]" 1>&2
  exit 1
}

generate_key(){
  local NAME=$1
  openssl genrsa -out csrs/${NAME}.key
}

generate_csr(){
  local NAME=$1
  openssl req -new -key csrs/${NAME}.key -out csrs/${NAME}.csr -subj "/emailAddress=${EMAIL},CN=Wormhole,C=US"
}

completion_instructions(){
  local NAME=$1
  echo "To complete the generation of a certificate, upload CSR csrs/${NAME}.csr to Apple Developer Portal" 1>&2
  echo "When done, download the new certificate to certs/<type>. Then run create_p12.sh" 1>&2
}

# Variables
NAME=$1
EMAIL=$2

if [[ -z $NAME ]]
then
  echo "Bundle Id is required" 1>&2
  usage_and_error
fi

if [[ -z $EMAIL ]]
then
  echo "Email is required" 1>&2
  usage_and_error
fi

if [[ ! -d csrs ]]
then
  echo "'csrs' directory not found" 1>&2
  echo "It appears you are running this script in the wrong directory." 1>&2
  usage_and_error
fi

generate_key $NAME
generate_csr $NAME
completion_instructions $NAME