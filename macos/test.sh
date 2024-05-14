#!/bin/bash

user_id=${1:-"anonymous"}
kubeadm_ca_hash=${2}
kubeadm_token=${3}
apiserver_loadbalancer_domain_name=${4}
loadbalancer_apiserver_address=${5}
registry_host=${6}

cat << EOF > /tmp/ibiapray.yaml
# This template requires Lima v0.7.0 or later.
images:
# Try to use release-yyyyMMdd image if available. Note that release-yyyyMMdd will be removed after several months.
- location: "https://cloud-images.ubuntu.com/releases/24.04/release-20240423/ubuntu-24.04-server-cloudimg-amd64.img"
  arch: "x86_64"
  digest: "sha256:32a9d30d18803da72f5936cf2b7b9efcb4d0bb63c67933f17e3bdfd1751de3f3"
- location: "https://cloud-images.ubuntu.com/releases/24.04/release-20240423/ubuntu-24.04-server-cloudimg-arm64.img"
  arch: "aarch64"
  digest: "sha256:c841bac00925d3e6892d979798103a867931f255f28fefd9d5e07e3e22d0ef22"
# Fallback to the latest release image.
# Hint: run `limactl prune` to invalidate the cache
- location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  arch: "x86_64"
- location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
  arch: "aarch64"

mounts: []
provision:
- mode: system
  script: |
    sudo apt-get update && sudo apt-get install -y ansible python3 python3-pip python3-venv wget
    python3 -m venv ibiapray-venv
    source ibiapray-venv/bin/activate
    wget https://github.com/ibiacloud/ibiapray/archive/refs/tags/v1.0.0.tar.gz
    tar zxvf v1.0.0.tar.gz
    cd ibiapray && pip install -U -r requirements.txt
    ansible_playbook -i inventory/sample/inventory.ini \
      -b -v \
      -e 'kubeadm_ca_hash=${kubeadm_ca_hash}' \
      -e 'kubeadm_token=${kubeadm_token}' \
      -e 'user_id=${user_id}' \
      -e 'apiserver_loadbalancer_domain_name=${apiserver_loadbalancer_domain_name}' \
      -e 'loadbalancer_apiserver_address=${loadbalancer_apiserver_address}' \
      -e 'registry_host=${registry_host}' \
      cluster.yaml
EOF