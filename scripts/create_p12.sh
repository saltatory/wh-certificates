#!/usr/bin/env bash

# Variables
NAME=$1
TYPE=$2
PASSWORD=$3

usage_and_error() {
  echo "create_p12.sh [NAME] {adhoc|distribution} [PASSWORD]" 1>&2
  echo "For a given type and bundle, generate a p12 file." 1>&2
  exit 1
}

generate_p12(){
  local DIRECTORY=$1
  local PASSWORD=$2
  openssl x509 -in ${DIRECTORY}/${NAME}.cer -inform DER -out ${DIRECTORY}/${NAME}.pem -outform PEM  
  openssl pkcs12 -export -passout pass:${PASSWORD} -inkey csrs/${NAME}.key -in ${DIRECTORY}/${NAME}.pem -out ${DIRECTORY}/${NAME}.p12 
}

if [[ -z $NAME ]]
then
  echo "Bundle Id is required" 1>&2
  usage_and_error
fi

if [[ -z $TYPE ]]
then
  case $TYPE in 
  "adhoc")
    # OK
    ;;
  "distribution")
    # OK
    ;;
  *)
    echo "Password is required" 1>&2
    usage_and_error
    ;;
  esac
fi

if [[ -z $PASSWORD ]]
then
  echo "Password is required" 1>&2
  usage_and_error
fi

if [[ ! -d ./csrs ]]
then
  echo "'csrs' directory not found" 1>&2
  echo "It appears you are running this script in the wrong directory." 1>&2
  usage_and_error
fi

DIRECTORY=certs/${TYPE}
echo $DIRECTORY

generate_p12 $DIRECTORY $PASSWORD