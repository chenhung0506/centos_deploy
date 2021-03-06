#!/bin/bash
set -e
function chk_root(){
  # Make sure only root can run this script
  if [[ $EUID -ne 0 ]]; then
    echo "error: you are not root" 1>&2
    return 1
  fi
}

# install docker-ce off line
function install_docker_off_line(){
  rpm_path='./pkgs/docker-ce'
  sudo rpm -ivh --replacefiles --replacepkgs $(find $rpm_path -type f -name '*.rpm')
  sudo systemctl start docker
  # Enable and start the docker service
  sudo systemctl enable docker --now
  # Set the permission
  sudo usermod -aG docker "${USER}"
  #更新用户组
  newgrp docker
  #確認 docker 成功啟動
  sudo systemctl status docker
  docker ps
}

# install docker-compose off line
function install_docker_compose_off_line(){
  compose_file_path='./pkgs/docker-compose'
  sudo cp "${compose_file_path}/docker-compose-Linux-x86_64 /usr/local/bin/docker-compose"
  sudo chmod +x /usr/local/bin/docker-compose
  docker-compose --version
}

# 1. Install docker and docker-compose
function install_docker(){
  # Setup the repository
  curl https://download.docker.com/linux/centos/docker-ce.repo \
    -o /etc/yum.repos.d/docker-ce.repo

  # Set the insecure registries
  mkdir -p /etc/docker
  #指定安装docker版本
  yum list docker-ce --showduplicates
  sudo yum install -y docker-ce-18.06.1.ce
  yum install -y docker-ce
  # Enable and start the docker service
  systemctl enable docker --now
  # Set the permission
  local user="${SUDO_USER:-${USER}}"
  usermod -aG docker "${user}"
  #更新用户组
  newgrp docker
  # Check
  sudo -u deployer docker ps
  # Docker-Compose
  local docker_compose_basepath='/usr/local/bin'
  local docker_compose_path="${docker_compose_basepath}/docker-compose"
  if [[ ! -x "${docker_compose_path}" ]]; then
    local docker_compose_version='1.24.1'
    curl -L \
      "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-$(uname -s)-$(uname -m)" \
      -o "${docker_compose_path}"
    
    chmod +x "${docker_compose_path}"
  fi

  # Check
  export PATH="${docker_compose_basepath}:${PATH}"
  docker-compose --version
}

function install_other_packages(){
  # 2. Install other packages
  if [[ "${WAN}" == 'true' ]]; then
    yum -y install chrony net-tools git;
  fi
  systemctl enable chronyd --now
}

# 3. Set sysctl
function set_sysctl(){
  local sysctl_conf='/etc/sysctl.conf'
  if ! cat "${sysctl_conf}" | grep -q 'vm.max_map_∂count = 262144'; then
  cat <<'EOF' | tee --append "${sysctl_conf}"
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
net.ipv4.ip_forward = 1
vm.max_map_count = 262144
kernel.pid_max = 4194303
fs.file-max = 1000000
net.ipv4.tcp_max_tw_buckets = 6000
net.netfilter.nf_conntrack_max=2097152
EOF
  #excute below command to init nf_conntrack_max config 
  modprobe ip_conntrack
  modprobe br_netfilter
  modprobe nf_conntrack
  #ls /proc/sys/net/bridge
fi

  cat "${sysctl_conf}"
  sysctl -p
}

# 4. Increase fd socket size (default = 1024)
function increase_fd_socket_size(){  
  LIMITS_FILE_PATH='/etc/security/limits.conf'
  if ! cat "${LIMITS_FILE_PATH}" | grep -q '*     soft    nofile          200000'; then
    echo '*     soft    nofile          200000'  | tee --append "${LIMITS_FILE_PATH}"
    echo '*     hard    nofile          200000'  | tee --append "${LIMITS_FILE_PATH}"
  fi
  cat "${LIMITS_FILE_PATH}"
}

# 5. Stop firewall
function stop_firewalld(){
  systemctl mask firewalld
  systemctl stop firewalld
  systemctl status firewalld || true
}

# 6. Stop NetworkManager
function stop_networkmanager(){
  systemctl disable NetworkManager
  systemctl stop NetworkManager
  systemctl status NetworkManager || true
}

# 7. Disable SELinux
function disable_selinux(){
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
  cat /etc/selinux/config
}

# For the Taipei office only
function set_docker_proxy(){
  mkdir -p '/etc/systemd/system/docker.service.d'
 
  cat <<'EOF' | tee '/etc/systemd/system/docker.service.d/http-proxy.conf'
[Service]
# Setup HTTP proxy for harbor.emotibot.com (so docker-reg.emotibot.com.cn images won't work)
Environment="HTTP_PROXY=http://180.169.210.141:55788" "NO_PROXY=.docker.io,.cloudflare.docker.com,gcr.io,.googleapis.com,docker-reg.emotibot.com.cn"
EOF
  
  systemctl daemon-reload
  systemctl restart docker 
  # Verify that the configuration has been loaded:
  systemctl show --property=Environment docker | grep 'PROXY'
  docker info | grep 'Proxy'
}

function main(){
  echo "WAN value=>  $WAN"
  chk_root
  install_other_packages
  set_sysctl
  increase_fd_socket_size
  stop_firewalld
  stop_networkmanager
  disable_selinux
  if [[ "${WAN}" == 'true' ]]; then
    install_docker
  elif [ "${WAN}" == 'false' ]; then
    install_docker_off_line
    install_docker_compose_off_line
  fi
  echo 'Done, You may reboot to take effect'
}

main "$@"
