#!/bin/bash -e

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
- location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  arch: "x86_64"
  # digest: "sha256:1718f177dde4c461148ab7dcbdcf2f410c1f5daa694567f6a8bbb239d864b525"
- location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
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
    sudo apt-get update && sudo apt-get install -y ansible python3 wget
    cd /tmp
    sudo apt-get install -y python3-pip
    wget https://github.com/ibiacloud/ibiapray/releases/download/v1.0.0/v1.0.0.tar.gz
    tar zxvf v1.0.0.tar.gz
    cd ibiapray && pip install -U -r requirements.txt
    export HOME=/home/$(whoami).linux
    ansible-playbook -i inventory/sample/inventory.ini \
      -b -v \
      -e 'kubeadm_ca_hash=${kubeadm_ca_hash}' \
      -e 'kubeadm_token=${kubeadm_token}' \
      -e 'user_id=${user_id}' \
      -e 'apiserver_loadbalancer_domain_name=${apiserver_loadbalancer_domain_name}' \
      -e 'loadbalancer_apiserver_address=${loadbalancer_apiserver_address}' \
      -e 'registry_host=${registry_host}' \
      cluster.yml
    touch /init-done
EOF

limactl start --containerd none /tmp/${APP}.yaml

if [ $? -ne 0 ];then
  echo "start fail"
  exit 1
fi

shell_file="~/.bashrc"

if [ "$(basename ${SHELL})" == "zsh" ];then
  shell_file="~/.zshrc"
fi

if [ -n "$(cat ${shell_file}|grep ${APP})" ];then
   sed -i "/^alias ${APP}=/d" ${shell_file} 
fi

echo "alias ${APP}='limactl shell ${APP}" >> ${shell_file}
