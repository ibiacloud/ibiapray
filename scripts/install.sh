#!/bin/bash

user_id=${1:-"anonymous"}
kubeadm_ca_hash=${2}
kubeadm_token=${3}
apiserver_loadbalancer_domain_name=${4}
loadbalancer_apiserver_address=${5}
registry_host=${6}

sudo apt-get update && sudo apt-get install -y ansible python3 python3-pip python3.12-venv wget
cd /tmp
python3 -m venv ibiapray-venv
source ibiapray-venv/bin/activate
wget https://github.com/ibiacloud/ibiapray/releases/download/v1.0.0/v1.0.0.tar.gz
tar zxvf v1.0.0.tar.gz
cd ibiapray && pip install -U -r requirements.txt
ansible-playbook -i inventory/sample/inventory.ini \
    -b -v \
    -e "kubeadm_ca_hash=${kubeadm_ca_hash}" \
    -e "kubeadm_token=${kubeadm_token}" \
    -e "user_id=${user_id}" \
    -e "apiserver_loadbalancer_domain_name=${apiserver_loadbalancer_domain_name}" \
    -e "loadbalancer_apiserver_address=${loadbalancer_apiserver_address}" \
    -e "registry_host=${registry_host}" \
    cluster.yaml