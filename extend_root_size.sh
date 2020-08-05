#!/bin/bash

function chk_root(){
  # Make sure only root can run this script
  if [[ $EUID -ne 0 ]]; then
    echo "error: you are not root" 1>&2
    return 1
  fi
}

function chk_cmd(){
  local cmd_name="$1"
  local pkg_name="$2"
  if ! command -v "${cmd_name}" &>/dev/null; then
    echo "error: no such command: ${cmd_name}, try 'yum install ${pkg_name} -y'" 1>&2
    return 1
  fi
  return 0
}

function fatal_handler(){
  local msg="$1"
  local exit_code="${2:-1}"
  echo "fatal: ${msg}" 1>&2
  exit "${exit_code}"
}

function main(){
  chk_root || exit "$?"
  chk_cmd 'growpart' 'cloud-utils-growpart' || exit "$?"
  chk_cmd 'xfs_growfs' 'xfsprogs' || exit "$?"

  growpart /dev/sda 3 || fatal_handler 'running growpart failed' "$?"
  xfs_growfs / || fatal_handler 'running xfs_growfs failed' "$?"
}

main "$@"
