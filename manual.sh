# 1. Install docker and docker-compose
 
# Uninstall old versions
sudo yum remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
 
# Setup the repository
 
sudo curl https://download.docker.com/linux/centos/docker-ce.repo \
  -o /etc/yum.repos.d/docker-ce.repo
 
# Set the insecure registries
sudo mkdir -p /etc/docker
cat <<'EOF' | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": [
      "docker-reg.emotibot.com.cn:55688",
      "172.16.101.70"
    ],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  }
}
EOF
 
#指定安装docker版本
yum list docker-ce --showduplicates
sudo yum install -y docker-ce-18.06.1.ce
 
# Enable and start the docker service
sudo systemctl enable docker --now
 
# Set the permission
sudo usermod -aG docker "${USER}"
#更新用户组
newgrp docker
# Check
docker ps
 
# Docker-Compose
DOCKER_COMPOSE_VERSION='1.24.1'
sudo curl -L \
  "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
 
sudo chmod +x /usr/local/bin/docker-compose
 
# Check
docker-compose --version
 




# 2. Install needed packages
sudo yum -y install chrony net-tools git; \
sudo systemctl enable chronyd --now
 






 # 3. Modify sysctl
SYSYCTL_CONF='/etc/sysctl.conf'
if ! cat "${SYSYCTL_CONF}" | grep -q 'vm.max_map_count = 262144'; then
  cat <<'EOF' | sudo tee --append "${SYSYCTL_CONF}"
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
net.ipv4.ip_forward = 1
vm.max_map_count = 262144
kernel.pid_max = 4194303
fs.file-max = 1000000
net.ipv4.tcp_max_tw_buckets = 6000
net.netfilter.nf_conntrack_max = 2097152
EOF
  modprobe nf_conntrack
fi
cat "${SYSYCTL_CONF}"
 
sudo sysctl -p




# 4. Increase fd socket size (default = 1024)
LIMITS_FILE_PATH='/etc/security/limits.conf'
if ! cat "${LIMITS_FILE_PATH}" | grep -q '*     soft    nofile          200000'; then
  echo '*     soft    nofile          200000'  | sudo tee --append "${LIMITS_FILE_PATH}"
  echo '*     hard    nofile          200000'  | sudo tee --append "${LIMITS_FILE_PATH}"
fi
cat "${LIMITS_FILE_PATH}"




# 5. Stop firewall
sudo systemctl mask firewalld
sudo systemctl stop firewalld
systemctl status firewalld
 



 # 6. Stop NetworkManager
sudo systemctl disable NetworkManager
sudo systemctl stop NetworkManager
systemctl status NetworkManager



# 7. Disable SELinux
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
cat /etc/selinux/config
 




 # 8. Reboot for SELinux
sudo reboot