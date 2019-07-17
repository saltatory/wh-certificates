#!/usr/bin/env bash

POLL_RATE=15
MAX_ERRORS=5
API_ROOT_V1="https://build-api.cloud.unity3d.com/api/v1"

usage_exit () {
	echo "Usage: $0"  1>&2
    echo "  -a|--api-key <api-key>, Specify API Key. Overrides UNITY_CLOUD_BUILD_API_KEY."  1>&2
    echo "  -o|--organization <organization>, Organization ID." 1>&2
    echo "  -cr|--credentials <credentials>, The UID of the UCB Credentials to Update."  1>&2
    echo "  -de|--description <credentials description>, The description for the credentials."  1>&2
    echo "  -ce|--certificate <certificate>, The path to the certificate file." 1>&2
    echo "  -pk|--private-key <private key>, The path to the private key file." 1>&2
    echo "  -pr|--provisioning-profile <provisioning profile>, The path to the provisioning profile file." 1>&2
    echo "  -pp|--passphrase <passphrase>, The passphrase of the credentials." 1>&2
	exit 1;
}

usage_error() {
	echo "Invalid Parameter: $1" 1>&2
	usage_exit
}

while [[ $# -gt 0 ]]
do

  option=$1

  case "${option}" in
      -a|--api-key)
          apikey=${2}
          shift
          shift
          ;;
      -o|--organization)
          organization=${2}
          shift
          shift
          ;;
      -cr|--credentials)
          credentials=${2}
          shift
          shift
          ;;
      -de|--description)
          credentials_description=${2}
          shift
          shift
          ;;
      -ce|--certificate)
          certificate=${2}
          shift
          shift
          ;;
      -pk|--private-key)
          private_key=${2}
          shift
          shift
          ;;
      -pr|--provisioning-profile)
          provisioning_profile=${2}
          shift
          shift
          ;;
      -pp|--passphrase)
          passphrase=${2}
          shift
          shift
          ;;
      *)
          usage_error "Invalid Option ${option}"
          shift
          ;;
  esac

done

# Assign default arguments, if necessary

if [ -z ${apikey} ]
then
  apikey=${UNITY_CLOUD_BUILD_API_KEY}
fi

# Check arguments

if [ -z "${apikey}" ]
then
  echo "API key not specified."
  usage_exit
elif [ -z "${organization}" ]
then
  echo "Organization not specified"
  usage_exit
elif [ -z "${credentials}" ]
then
  echo "Credentials ID not specified"
  usage_exit
elif [ -z "${credentials_description}" ]
then
  echo "Credentials description not specified"
  usage_exit
elif [ -z "${certificate}" ]
then
  echo "Certificate file not specified."
  usage_exit
elif [ -z "${private_key}" ]
then
  echo "Priveate key file not specified."
  usage_exit
elif [ -z "${provisioning_profile}" ]
then
  echo "Priveate key file not specified."
  usage_exit
fi

# Read passphrase if not specified.

if [ -z "${passphrase}" ]
then
  read -p "Enter Passphrase: " -s passphrase
fi

# Check for necessary files to exist.

if [ ! -f "${certificate}" ]
then
  echo "Certificate file not found: ${certificate}"
  usage_exit
elif [ ! -f "${private_key}" ]
then
  echo "Private key file not found: ${private_key}"
  usage_exit
elif [ ! -f "${provisioning_profile}" ]
then
  echo "Provisioning profile file not found: ${provisioning_profile}"
  usage_exit
fi

# Make Temporary Files and assign traps

t_cer_der=$(mktemp) || (echo "Failed to make temp file." && exit 1)
t_cer_pem=$(mktemp) || (echo "Failed to make temp file." && exit 1)
t_key_pem=$(mktemp) || (echo "Failed to make temp file." && exit 1)
t_ouput_p12=$(mktemp) || (echo "Failed to make temp file." && exit 1)
t_provisioning_profile=$(mktemp) || (echo "Failed to make temp file." && exit 1)
trap 'rm -f "$t_cer_pem"; rm -f "$t_cer_der";rm -f "$t_key_pem";rm -f "$t_ouput_p12";rm -f "$t_provisioning_profile"' EXIT

# See: https://docs.fastlane.tools/actions/match/
# Decrypts both key and certificate to a temporary file.

openssl aes-256-cbc -k "${passphrase}" -in "${certificate}" -out "${t_cer_der}" -a -d -md md5
status=$?

if [ ${status} -ne 0 ]
then
  >&2 echo "Failed to decrypt certificate."
  exit $status
fi

openssl aes-256-cbc -k "${passphrase}" -in "${private_key}" -out "${t_key_pem}" -a -d -md md5
status=$?

if [ ${status} -ne 0 ]
then
  >&2 echo "Failed to decrypt private key."
  exit $status
fi

openssl aes-256-cbc -k "${passphrase}" -in "${provisioning_profile}" -out "${t_provisioning_profile}" -a -d -md md5
status=$?

if [ ${status} -ne 0 ]
then
  >&2 echo "Failed to decrypt provisioning profile."
  exit $status
fi

# Converts the certificate to a PRM from a DER file

openssl x509 -inform der -in "${t_cer_der}" -outform pem -out "${t_cer_pem}"
status=$?

if [ ${status} -ne 0 ]
then
  >&2 echo "Failed to covnert certificate."
  exit $status
fi

# Finally, generates the output .p12 file to be pushed to UCB.

openssl pkcs12 -export -out "${t_ouput_p12}" -inkey "${t_key_pem}" -in "${t_cer_pem}" -password "pass:${passphrase}"
status=$?

if [ ${status} -ne 0 ]
then
  >&2 echo "Failed to convert private key."
  exit $status
fi

# Lastly, uploads the new credentials and provisioning profile to UCB

curl \
  --fail \
  -X PUT \
  -F label="${credentials_description} - $(date)" \
  -F fileCertificate="@${t_ouput_p12}" \
  -F fileProvisioningProfile="@${t_provisioning_profile}" \
  -F certificatePass="${passphrase}" \
  -H "Content-Type: multipart/form-data" \
  -H "Authorization: Basic ${apikey}" \
  "https://build-api.cloud.unity3d.com/api/v1/orgs/${organization}/credentials/signing/ios/${credentials}"

status=$?

if [ ${status} -ne 0 ]
then
  >&2 echo "Failed to update UCB Credentials"
  exit $status
fi
