#!/bin/bash

apt install wget

CONT_CONF_FILE="/version.txt"

function addVarToConf {
  local variable="$1"
  local value="$2"
  if [ ! -z "${variable}" ]; then
    echo ${variable}=${value} >> ${CONT_CONF_FILE}
  fi
}

function readVarFromConf {
  local variable="$1"
  local -n readVarFromConf_value=$2
  if [ ! -z "${variable}" ]; then
    readVarFromConf_value="$(grep -w ${variable} ${CONT_CONF_FILE} | cut -d'=' -f2 | tail -n 1)"
  else
    readVarFromConf_value=NULL
  fi
}

function getVersionInfo {
  local version="$1"
  local token="$2"
  local -n getVersionInfo_remoteVersion=$3
  local -n getVersionInfo_remoteFile=$4

  local channel
  local tokenNeeded=1
  if [ ! -z "${PLEX_UPDATE_CHANNEL}" ] && [ "${PLEX_UPDATE_CHANNEL}" > 0 ]; then
    channel="${PLEX_UPDATE_CHANNEL}"
  elif [ "${version,,}" = "beta" ]; then
    channel=8
  elif [ "${version,,}" = "public" ]; then
    channel=16
    tokenNeeded=0
  else
    channel=8
  fi

  # Read container architecture info from file created when building Docker image
  readVarFromConf "plex_build" plexBuild
  readVarFromConf "plex_distro" plexDistro

  local url="https://artifacts.plex.tv/plex-media-server-experimental/1.40.6.8849-a0fe53a79/debian/plexmediaserver_1.40.6.8849-a0fe53a79_amd64.deb"
  wget https://artifacts.plex.tv/plex-media-server-experimental/1.40.6.8849-a0fe53a79/debian/plexmediaserver_1.40.6.8849-a0fe53a79_amd64.deb
  dpkg -i plexmediaserver_1.40.6.8838-0f37280c7_amd64.deb

  local versionInfo="$(curl -s "${url}")"

  # Get update info from the XML.  Note: This could countain multiple updates when user specifies an exact version with the lowest first, so we'll use first always.
  getVersionInfo_remoteVersion=$(echo "${versionInfo}" | sed -n 's/.*Release.*version="\([^"]*\)".*/\1/p')
  getVersionInfo_remoteFile=$(echo "${versionInfo}" | sed -n 's/.*file="\([^"]*\)".*/\1/p')
}


function installFromUrl {
  installFromRawUrl "https://plex.tv/${1}"
}

function installFromRawUrl {
  local remoteFile="$1"
  curl -J -L -o /tmp/plexmediaserver.deb "${remoteFile}"
  local last=$?

  # test if deb file size is ok, or if download failed
  if [[ "$last" -gt "0" ]] || [[ $(stat -c %s /tmp/plexmediaserver.deb) -lt 10000 ]]; then
    echo "Failed to fetch update"
    exit 1
  fi

  dpkg -i --force-confold --force-architecture  /tmp/plexmediaserver.deb
  rm -f /tmp/plexmediaserver.deb
}
