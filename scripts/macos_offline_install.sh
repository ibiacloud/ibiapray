#!/bin/bash

APP=ibiacloud

user_id=${1:-"anonymous"}
kubeadm_ca_hash=${2}
kubeadm_token=${3}
apiserver_loadbalancer_domain_name=${4}
loadbalancer_apiserver_address=${5}
registry_host=${6}

# Install lima
if [ -z "$(which limactl)" ];then
  brew update && brew install lima
fi

if [ -n "$(limactl list -q ${APP})" ];then
  limactl stop ${APP} || true
  limactl delete ${APP} 
fi

cat << EOF > /tmp/${APP}.yaml
# This template requires Lima v0.7.0 or later.
images:
# Try to use release-yyyyMMdd image if available. Note that release-yyyyMMdd will be removed after several months.
- location: "http://127.0.0.1:8080/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  arch: "x86_64"
  # digest: "sha256:1718f177dde4c461148ab7dcbdcf2f410c1f5daa694567f6a8bbb239d864b525"
- location: "http://127.0.0.1:8080/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
  arch: "aarch64"
  # digest: "sha256:f6bf7305207a2adb9a2e2f701dc71f5747e5ba88f7b67cdb44b3f5fa6eea94a3"
# Fallback to the latest release image.
# Hint: run `limactl prune` to invalidate the cache
# - location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
#   arch: "x86_64"
# - location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
#   arch: "aarch64"

mounts: []
containerd:
  system: false
  user: false
portForwards:
- guestPortRange: [30000, 32767]
  hostPortRange: [30000, 32767]
- guestPort: 80
  hostPort: 9080
provision:
- mode: system
  script: |
    [ -f /init-done ] && exit 0
    cat << EOF > /etc/apt/sources.list
    # 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
    deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
    # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
    deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
    # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
    deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
    # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse

    # 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
    deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
    # deb-src http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

    # 预发布软件源，不建议启用
    # deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
    # # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
    EOF

    sudo apt-get update && sudo apt-get install -y ansible python3 wget
    sudo apt-get install -y python3-pip
    python -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple --upgrade pip
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

    # only start one
    cd /tmp
    wget https://github.com/ibiacloud/ibiapray/releases/download/v1.0.0/v1.0.0.tar.gz
    tar zxvf v1.0.0.tar.gz
    cd ibiapray && pip install -U -r requirements.txt
    curl -o inventory/sample/group_vars/all/offline.yml -s https://raw.githubusercontent.com/ibiacloud/ibiapray/develop/scripts/offline.yml
    export HOME=/home/$(whoami).linux
    ansible-playbook -i inventory/sample/inventory.ini \
      -b -v \
      -e "kubeadm_ca_hash=${kubeadm_ca_hash}" \
      -e "kubeadm_token=${kubeadm_token}" \
      -e "user_id=${user_id}" \
      -e "apiserver_loadbalancer_domain_name=${apiserver_loadbalancer_domain_name}" \
      -e "loadbalancer_apiserver_address=${loadbalancer_apiserver_address}" \
      -e "registry_host=${registry_host}" \
      -e "files_repo=http://host.lima.internal:8080" \
      cluster.yml
    touch /init-done
EOF

limactl start --containerd none /tmp/${APP}.yaml

if [ -z "$(cat ~/.bashrc|grep ${APP})" ];then
  echo "alias ${APP}='limactl shell ${APP} sudo nerdctl --address unix:///var/run/containerd/containerd.sock'" >> ~/.bashrc
  source ~/.bashrc
fi

# rm -rf /tmp/${APP}.yaml