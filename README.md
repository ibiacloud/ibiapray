[TOC]

## For Ubuntu
### Requirements

- A Computer can connect to internet
- System: Ubuntu 22.04
- Nvidia Driver: graphics memory >= 12G

### Add Node

> Below are serveral ways to join a node or many nodes into out network

- Get Join Token, you can get two tokens at [Here](https://cloud.ibia.ai/me/nodes), one names `kubeadm_ca_hash` and other `kubeadm_token`, the token expired after `24h`, this two tokens will be used at below step.

- Download ibiapray(if you already installed docker, you can ignore this step)

    ```sh
    sudo apt-get update && sudo apt-get install -y ansible python3 python3-pip python3-venv wget
    python3 -m venv ibiapray-venv
    source ibiapray-venv/bin/activate
    wget https://github.com/ibiacloud/ibiapray/archive/refs/tags/v1.0.0.tar.gz
    tar zxvf v1.0.0.tar.gz
    cd ibiapray && pip install -U -r requirements.txt
    ```

- If you have many nodes to deploy, you need modify file `inventory/sample/inventory.ini` and the file conent like this:

    ```ini
    # ## 'ansible_host' node host
    # ## 'ansible_ssh_user' ssh connect user, default current user
    # ## 'ansible_ssh_user' ssh connect port, default 22
    # ## if you have public ip set 'access_ip'
    [kube-node]
    node2 ansible_connection=local local_release_dir={{ansible_env.HOME}}/releases access_ip=127.0.0.1
    node2 ansible_host=172.31.31.10
    node3 ansible_host=172.31.31.11
    node4 ansible_host=172.31.31.12
    node5 ansible_host=172.31.31.13
    ```

- Starting custom deployment

    ```sh
    # if you have many nodes
    ansible-playbook -i inventory/sample/inventory.ini -b -v -e 'kubeadm_ca_hash=xxxx' -e 'kubeadm_token=yyy' -e 'user_id=xxx' cluster.yaml
    ```

    If you are using AWS EC2, after install you need execute this two scripts at below

    ```sh
    sudo apt-get update -y
    sudo apt-get upgrade -y linux-aws
    sudo apt-get upgrade -y
    sudo reboot
    ```

    After reboot execute

    ```sh
    sudo apt-get install -y gcc make linux-headers-$(uname -r)
    cat << EOF | sudo tee --append /etc/modprobe.d/blacklist.conf
    blacklist vga16fb
    blacklist nouveau
    blacklist rivafb
    blacklist nvidiafb
    blacklist rivatv
    EOF

    cat <<EOF |sudo tee --append /etc/default/grub
    GRUB_CMDLINE_LINUX="rdblacklist=nouveau"
    EOF

    sudo update-grub
    ```

- Add Nodes

    You may want to add more nodes into out network, this can be done by re-running the `cluster.yaml` playbook, This is especially helpful when doing something like autoscaling your clusters.

    - Add the new nodes to your `inventory.ini`
    - Run the ansible-playbook command, shubstituting `cluster.yaml` for `scale.yaml`

    ```sh
    ansible-playbook -i inventory/sample/inventory.ini -b -v -e 'kubeadm_ca_hash=xxxx' -e 'kubeadm_token=yyy' -e 'user_id=xxx' scale.yaml
    ```

- Remove Nodes

    You may want to remove nodes from you existing inventory, This can be done by re-running the `remove-node.yaml` playbook, you can remove the node and install it again.
    Use -e 'node=<nodename>,<nodename2>' to select the node(s) you want to delete.

    ```sh
    ansible-playbook -i inventory/sample/inventory.ini -b -v -e 'node=nodename,nodename2' remove-node.yaml
    ```

    Or remove node from our [Cloud](https://cloud.ibia.ai/me/nodes).


## For Macos

```sh
curl -s https://raw.githubusercontent.com/ibiacloud/ibiapray/develop/macos/install.sh | bash -s --  'aws' 'xxx' 'xxx' 'cloud-us-east-1.example.com' '127.0.0.1' 'registry.example.com'
```

Or 

```sh
brew update && brew install lima
limactl start ibiacloud template:ubuntu
limactl shell ibiacloud
sudo apt-get update && sudo apt-get install -y ansible python3 python3-pip python3-venv wget
python3 -m venv ibiapray-venv
source ibiapray-venv/bin/activate
wget https://github.com/ibiacloud/ibiapray/archive/refs/tags/v1.0.0.tar.gz
tar zxvf v1.0.0.tar.gz
cd ibiapray && pip install -U -r requirements.txt
ansible-playbook -i inventory/sample/inventory.ini -b -v -e 'kubeadm_ca_hash=xxxx' -e 'kubeadm_token=yyy' -e 'user_id=xxx' cluster.yaml
```