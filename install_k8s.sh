#!/bin/bash -eux
yum -y install epel-release
yum --enablerepo=epel -y install sshpass
yum -y install firewalld

yum -y groupinstall 'Development Tools'
yum -y install openssl-devel libffi libffi-devel gcc
yum -y install net-snmp net-snmp-utils
yum -y install python3 python3-pip python3-devel
pip3 install ansible==2.3.0
pip3 install markupsafe httplib2 requests jproperties

echo "------- Disable SELinux --------"
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "------ Update Firewalls --------"
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --permanent --add-port=10255/tcp
firewall-cmd –-reload

echo "---- Update IPTable Settings ----"
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "---- Setup Kubernetes Repo ----"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
sslverify=0
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

echo "-- Install kubelet, kubeadm, and kubectl --"
yum install -y kubeadm kubectl kubelet docker
systemctl enable kubelet
systemctl restart kubelet
systemctl enable docker
systemctl start docker

echo "-------- Disable Swap --------"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "---- Initialize Kubernetes ----"
# kubeadm init --pod-network-cidr=192.168.0.0/16
kubeadm init
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# cat <<EOF > /etc/NetworkManager/conf.d/calico.conf
# [keyfile]
# unmanaged-devices=interface-name:cali*;interface-name:tunl*
# EOF

# kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml
export kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl get nodes -o wide
sleep 20s

echo "-------- Kubernetes Node state ---------"
export KUBECONFIG=/etc/kubernetes/kubelet.conf
kubectl get nodes -o wide
kubectl get services --all-namespaces
kubectl get pods --all-namespaces

echo "---------- Install helm -----------"
yum -y install wget curl
wget https://get.helm.sh/helm-v3.2.1-linux-amd64.tar.gz
tar -zxvf helm-v3.2.1-linux-amd64.tar.gz
chmod u+x linux-amd64/helm
mv -f linux-amd64/helm /usr/local/bin/helm
cp /usr/local/bin/helm /bin/helm
which helm
helm version
