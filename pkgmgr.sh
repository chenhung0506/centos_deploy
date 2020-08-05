#!/bin/bash
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_BASE_DIR="${PWD}/pkgs"

function show_help(){
  local USAGE="Usage: ${0##*/} sub command [pkg...]

  Install
  e.g. ${0##*/} install git net-tools wget

  Remove
  e.g. ${0##*/} remove git net-tools wget

  Download
  e.g. ${0##*/} download git net-tools wget
"
  echo "${USAGE}"
}

function chk_root(){
  # Make sure only root can run this script
  if [[ "${EUID}" -ne '0' ]]; then
    echo "error: you are not root" 1>&2
    return 1
  fi
}

function chk_path(){
  local path="$1"
  if [[ ! -d "${path}" ]]; then
    echo "error: no such ${path} directory" 1>&2
    return 1
  fi
  return 0
}

function get_pkg_paths(){
  local pkg_dir_names="$1"
  local pkg_dir_name
  local pkg_paths=()
  if [[ -z "${pkg_dir_names}" ]]; then
    pkg_paths=($(find "${PKG_BASE_DIR}" -type f -name '*.rpm'))
  else
    for pkg_dir_name in ${pkg_dir_names[@]}; do
      if chk_path "${PKG_BASE_DIR}/${pkg_dir_name}"; then
        pkg_paths+=($(find "${PKG_BASE_DIR}/${pkg_dir_name}" -type f -name '*.rpm'))
      else
        echo "error: wrong path '${pkg_dir_name}', interrupt" 1>&2
        return 1
      fi
    done
  fi
  if [[ -n "${pkg_paths[@]}" ]]; then
    echo "${pkg_paths[@]}"
    return 0
  else
    echo "error: failed to get pkg path(s)" 1>&2
    return 1    
  fi
}

# install docker-ce
function install(){
  local pkg_paths pkg_dir_names="$@"
  pkg_paths="$(get_pkg_paths "${pkg_dir_names}")" || exit "$?"
  rpm -ivh --replacefiles --replacepkgs ${pkg_paths}
}

# remove docker-ce
function remove(){
  local rc pkg_name pkg_names pkg_dir_names="$@"
  pkg_paths="$(get_pkg_paths "${pkg_dir_names}")" || exit "$?"
  # Remove dirname, extensions, and duplications
  pkg_names="$(echo "${pkg_paths}" | xargs basename -a | sed 's/\.[^.]*$//' | awk '!x[$0]++')"

  for pkg_name in ${pkg_names}; do
    rpm -e --nodeps --test "${pkg_name}" || { echo "error: test failed with pkg: ${pkg_name}"; return 1; }
  done

  for pkg_name in ${pkg_names}; do
    rpm -e --nodeps "${pkg_name}"
    rc="$?"
    if [[ "${rc}" -eq '0' ]]; then
      echo "info: successfully removed pkg: ${pkg_name}"
    else
      echo "error: download failed with pkg: ${pkg_name}" 1>&2
      return 1
    fi
  done
}

function download(){
  local rc dir use_sudo='false' pkg_name pkg_names="$@"

  if [[ -z "${pkg_names}" ]]; then
    echo 'please input package names' 1>&2
    return 1
  fi

  if [[ -n "${SUDO_UID}" ]] && [[ -n "${SUDO_GID}" ]]; then
    use_sudo='true'
  fi

  for pkg_name in ${pkg_names}; do
    dir="${PKG_BASE_DIR}/${pkg_name}"
    mkdir -p "${dir}"
    yum install --downloadonly --downloaddir=${dir} "${pkg_name}"
    rc="$?"
    if [[ "${rc}" -ne '0' ]]; then
      echo "error: download failed with pkg: ${pkg_name}" 1>&2
      return 1
    fi
    if "${use_sudo}"; then
      chown -R "${SUDO_UID}:${SUDO_GID}" "${dir}"
    fi
  done
}

function remove_old_docker(){
  yum remove docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-selinux \
    docker-engine-selinux \
    docker-engine
}

function main(){
  chk_root || exit "$?"

  case "$1" in
  'install')
    shift
    install "$@"
    ;;
  'remove')
    shift
    remove "$@"
    ;;
  'download')
    shift
    download "$@"
    ;;
  'remove-old-docker')
    remove_old_docker
    ;;
  *)
    show_help
    exit 1
    ;;
  esac

  exit "$?"
}

main "$@"
