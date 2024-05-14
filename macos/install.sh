#!/bin/bash

APP=ibiacloud1

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
- location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  arch: "x86_64"
  # digest: "sha256:da76b0ef1cd45939f0d14ca11dd4dfabbe13b94d2ec144d54c805d1baf852e67"
- location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
  arch: "aarch64"
  digest: "sha256:3d803c0913843e6df900002e65d5caeff1d8f257d217438316251be1e1cd977c"
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
- guestPort: 80
  hostPort: 9080
provision:
- mode: system
  script: |
    sudo apt-get update && sudo apt-get install -y ansible python3 python3-pip python3.12-venv wget
    cd /tmp
    python3 -m venv ibiapray-venv
    source ibiapray-venv/bin/activate
    wget https://github.com/ibiacloud/ibiapray/releases/download/v1.0.0/v1.0.0.tar.gz
    tar zxvf v1.0.0.tar.gz
    cd ibiapray && pip install -U -r requirements.txt
    ansible-playbook -i inventory/sample/inventory.ini \
      -b -v \
      -e 'kubeadm_ca_hash=${kubeadm_ca_hash}' \
      -e 'kubeadm_token=${kubeadm_token}' \
      -e 'user_id=${user_id}' \
      -e 'apiserver_loadbalancer_domain_name=${apiserver_loadbalancer_domain_name}' \
      -e 'loadbalancer_apiserver_address=${loadbalancer_apiserver_address}' \
      -e 'registry_host=${registry_host}' \
      cluster.yaml
EOF

limactl start --containerd none /tmp/${APP}.yaml

if [ -z "$(cat ~/.bashrc|grep ${APP})" ];then
  echo "alias ${APP}='limactl shell ${APP} sudo nerdctl --address unix:///var/run/containerd/containerd.sock'" >> ~/.bashrc
  source ~/.bashrc
fi