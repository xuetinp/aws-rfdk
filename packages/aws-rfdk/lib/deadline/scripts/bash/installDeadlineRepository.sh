#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# exit when any command fails
set -xeuo pipefail

MIN_DEADLINE_VERSION_REPO_NO_ROOT="10.1.18"
USAGE="Usage: $0 -i <installer-s3-path> -p <local-installer-path> -v <deadline-version>

This script downloads the deadline repository installer and executes it.

Required arguments:
  -i s3 path for the deadline repository installer.
  -p Path where deadline repository needs to be installed.
  -v Deadline Repository Version being installed.

Optional arguments
  -s Deadline Repository settings file to import.
  -o The UID[:GID] that this script will chown the Repository files for. If GID is not specified, it defults to be the same as UID.
  -c Secrets management admin credentials ARN. If this parameter is specified, secrets management will be enabled.
  -r Region where stacks are deployed. Required to get secret management credentials."

while getopts "i:p:v:s:o:c:r:" opt; do
  case $opt in
    i) S3PATH="$OPTARG"
    ;;
    p) PREFIX="$OPTARG" 
    ;;
    v) DEADLINE_REPOSITORY_VERSION="$OPTARG"
    ;;
    s) DEADLINE_REPOSITORY_SETTINGS_FILE="$OPTARG"
    ;;
    o) DEADLINE_REPOSITORY_OWNER="$OPTARG"
    ;;
    c) SECRET_MANAGEMENT_ARN="$OPTARG"
    ;;
    r) AWS_REGION="$OPTARG"
    ;;
    /?)
      echo "$USAGE"
      exit 1
    ;;
  esac
done

if [ -z "${S3PATH+x}" ] || \
   [ -z "${PREFIX+x}" ] || \
   [ -z "${DEADLINE_REPOSITORY_VERSION+x}" ]; then
  echo "ERROR: Required arguments are missing."
  echo "$USAGE"
  exit 1
fi

# check if repository is already installed at the given path
REPOSITORY_FILE_PATH="$PREFIX/settings/repository.ini"
CONNECTION_FILE_PATH="$PREFIX/settings/connection.ini"

# Run the Function that the Database Connection created to set up the installer arguments.
declare -A INSTALLER_DB_ARGS
configure_database_installation_args

if test -f "$REPOSITORY_FILE_PATH"; then
    echo "File $REPOSITORY_FILE_PATH exists. Validating Database Connection"
    # File Exists

    INSTALLER_DB_HOSTNAME=${INSTALLER_DB_ARGS["--dbhost"]}
    INSTALLER_DB_PORT=${INSTALLER_DB_ARGS["--dbport"]}

    # Additionally, vadlidate the DB endpoint.
    source $CONNECTION_FILE_PATH > /dev/null 2>&1 || true
    if [ "$Hostname" != "$INSTALLER_DB_HOSTNAME" ] || [ "$Port" != "$INSTALLER_DB_PORT" ]; then
        echo "ERROR: Repository pre-exists but configured database endpoint($Hostname:$Port) does not match with provided database endpoint($INSTALLER_DB_HOSTNAME:$INSTALLER_DB_PORT)."
        exit 1
    fi
    echo "Database Connection is valid.  Validating Deadline Version."
    
    # Following runs the .ini file as a script while suppressing all the errors. This creates bash variables with
    # the key's name and sets its value to the value specified in .ini file.
    # This is a quick way to read the .ini values but is not a full-proof way. Since we dont have common keys in
    # multiple sections of the config files, this approach will work correctly.
    # The proper way to achieve this is to use a ini config manager tool to get the value of required key.
    source $REPOSITORY_FILE_PATH > /dev/null 2>&1 || true
    if [[ "$Version" = "$DEADLINE_REPOSITORY_VERSION" ]]; then
        echo "Repository version $DEADLINE_REPOSITORY_VERSION already exists at path $REPOSITORY_FILE_PATH."
    else
        SplitVersion=(${Version//./ })
        SplitRepoVersion=(${DEADLINE_REPOSITORY_VERSION//./ })

        if [[ ${SplitVersion[0]} != ${SplitRepoVersion[0]} ]] || [[ ${SplitVersion[1]} != ${SplitRepoVersion[1]} ]]; then
            echo "ERROR: Repository pre-exists but configured Repository Version (${Version}) has a different Major or Minor Version than the provided installer (${DEADLINE_REPOSITORY_VERSION})."
            exit 1
        fi
    fi
fi

REPO_INSTALLER=/tmp/repo_installer.run

aws s3 cp $S3PATH $REPO_INSTALLER
chmod +x $REPO_INSTALLER

set +x

REPO_ARGS=()

for key in "${!INSTALLER_DB_ARGS[@]}"; do
  REPO_ARGS+=("${key}" "${INSTALLER_DB_ARGS[$key]}")
done

if [ ! -z "${DEADLINE_REPOSITORY_SETTINGS_FILE+x}" ]; then
  if [ ! -f "$DEADLINE_REPOSITORY_SETTINGS_FILE" ]; then
    echo "ERROR: Repository settings file was specified but is not a file: $DEADLINE_REPOSITORY_SETTINGS_FILE."
    exit 1
  else
    REPO_ARGS+=("--importrepositorysettings" "true" "--repositorysettingsimportoperation" "append" "--repositorysettingsimportfile" "$DEADLINE_REPOSITORY_SETTINGS_FILE")
  fi
fi

if [ ! -z "${SECRET_MANAGEMENT_ARN+x}" ]; then
  sudo yum install -y jq
  SM_SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id=$SECRET_MANAGEMENT_ARN --region=$AWS_REGION)
  SM_SECRET_STRING=$(jq -r '.SecretString' <<< "$SM_SECRET_VALUE")
  SECRET_MANAGEMENT_USER=$(jq -r '.username' <<< "$SM_SECRET_STRING")
  SECRET_MANAGEMENT_PASSWORD=$(jq -r '.password' <<< "$SM_SECRET_STRING")
  if !([[ ${#SECRET_MANAGEMENT_PASSWORD} -ge 8 ]] && 
    echo $SECRET_MANAGEMENT_PASSWORD | grep -q [0-9] &&
    echo $SECRET_MANAGEMENT_PASSWORD | grep -q [a-z] &&
    echo $SECRET_MANAGEMENT_PASSWORD | grep -q [A-Z] &&
    echo $SECRET_MANAGEMENT_PASSWORD | grep -q [^[:alnum:]])
  then
    echo "ERROR: Admin password is too weak. It must be at least 8 characters long and contain at least one lowercase letter, one uppercase letter, one symbol and one digit."
    exit 1
  fi
  echo "Secrets management is enabled. Credentials are stored in secret: $SECRET_MANAGEMENT_ARN"
  REPO_ARGS+=("--installSecretsManagement" "true" "--secretsAdminName" "$SECRET_MANAGEMENT_USER" "--secretsAdminPassword" "$SECRET_MANAGEMENT_PASSWORD")
else
  echo "Secrets management is not enabled."
fi

INSTALL_AS_NON_ROOT_CMD=""
if [[ -n "${DEADLINE_REPOSITORY_OWNER+x}" ]]; then
  if [[ ! "$DEADLINE_REPOSITORY_OWNER" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
    echo "ERROR: Deadline Repository owner is invalid: ${DEADLINE_REPOSITORY_OWNER}"
    exit 1
  fi
  REPOSITORY_OWNER_UID="${DEADLINE_REPOSITORY_OWNER%:*}"
  REPOSITORY_OWNER_GID="${DEADLINE_REPOSITORY_OWNER#*:}"

  if [[ -z $REPOSITORY_OWNER_GID ]]; then
    echo "Repository owner GID not specified. Defaulting to UID $REPOSITORY_OWNER_UID"
    REPOSITORY_OWNER_GID=$REPOSITORY_OWNER_UID
  fi

  EXISTING_GROUP=$(id -g $REPOSITORY_OWNER_UID)
  if [[ $? -eq 0 ]]; then
    # UID already taken, make sure the GID matches
    if [[ ! $EXISTING_GROUP -eq $REPOSITORY_OWNER_GID ]]; then
      echo "ERROR: Deadline Repository owner UID $REPOSITORY_OWNER_UID is already in use and has incorrect GID. Got GID $EXISTING_GROUP, expected $REPOSITORY_OWNER_GID"
      exit 1
    fi
  else
    # Create the group
    groupadd deadline-rcs-user -g $REPOSITORY_OWNER_GID

    # Create the user
    useradd deadline-rcs-user -u $REPOSITORY_OWNER_UID -g $REPOSITORY_OWNER_GID
  fi

  # Determine whether we can run the installer as the user that will own the repository
  VERSION_COMPONENTS=(${DEADLINE_REPOSITORY_VERSION//./ })
  MIN_VERSION_COMPONENTS=(${MIN_DEADLINE_VERSION_REPO_NO_ROOT//./ })
  if !([[ ${VERSION_COMPONENTS[0]} -lt ${MIN_VERSION_COMPONENTS[0]} ]] || \
       [[ ${VERSION_COMPONENTS[1]} -lt ${MIN_VERSION_COMPONENTS[1]} ]] || \
       [[ ${VERSION_COMPONENTS[2]} -lt ${MIN_VERSION_COMPONENTS[2]} ]])
  then
    echo "Deadline Repository installer will be run as UID=$REPOSITORY_OWNER_UID"
    INSTALL_AS_NON_ROOT_CMD="sudo -u #$REPOSITORY_OWNER_UID"
  fi
fi

# The syntax ${array[@]+"${array[@]}"} is a way to get around the expansion of an empty array raising an unbound variable error since this script
# sets the "u" shell option above. This is a use of the ${parameter+word} shell expansion. If the value of "parameter" is unset, nothing will be
# substituted in its place. If "parameter" is set, then the value of "word" is used, which is the expansion of the populated array.
# Since bash treats the expansion of an empty array as an unset variable, we can use this pattern expand the array only if it is populated.
$INSTALL_AS_NON_ROOT_CMD $REPO_INSTALLER --mode unattended --setpermissions false --prefix "$PREFIX" --installmongodb false --backuprepo false ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}

if [[ -z "$INSTALL_AS_NON_ROOT_CMD" ]] && [[ -n "${REPOSITORY_OWNER_UID+x}" ]]; then
  echo "Changing ownership of Deadline Repository files to UID=$REPOSITORY_OWNER_UID GID=$REPOSITORY_OWNER_GID"
  sudo chown -R "$REPOSITORY_OWNER_UID:$REPOSITORY_OWNER_GID" "$PREFIX"
fi

set -x

echo "Script completed successfully."
