# Installing kubernetes

This is a casual guide for installing a 3-node HA kubernetes cluster.

The following is assumed:

- `haproxy` configured and running at 192.168.1.99 as load balancer
- 3x Alma Linux or Debian machines running on consecutive IPs from 192.168.1.90, I've named them `lucky`, `dusty` and `ned`.

## Install packages on all nodes

### Debian

```sh
KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33

apt install -y apt-transport-https ca-certificates curl gnupg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list

swapoff -a
echo br_netfilter | tee /etc/modules-load.d/br_netfilter.conf
modprobe br_netfilter
echo net.ipv4.ip_forward = 1 | tee /etc/sysctl.d/99-ip-forward.conf
sysctl -w net.ipv4.ip_forward=1
echo vm.nr_hugepages = 1024 | tee /etc/sysctl.d/99-hugepages.conf
sysctl -w vm.nr_hugepages=1024

apt update && apt install -y cri-o kubelet kubeadm

systemctl enable --now crio.service
systemctl enable --now kubelet.service
```

### Alma Linux

```sh
KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33

cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOF

cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/rpm/repodata/repomd.xml.key
EOF

swapoff -a
echo br_netfilter | tee /etc/modules-load.d/br_netfilter.conf
modprobe br_netfilter
echo net.ipv4.ip_forward = 1 | tee /etc/sysctl.d/99-ip-forward.conf
sysctl -w net.ipv4.ip_forward=1
echo vm.nr_hugepages = 1024 | tee /etc/sysctl.d/99-hugepages.conf
sysctl -w vm.nr_hugepages=1024

dnf install -y cri-o kubelet kubeadm

systemctl enable --now crio.service
systemctl enable --now kubelet.service
```

## Initialise nodes

Add firewall rules if needed, e.g.

```sh
IPS=(
  192.168.1.0/24
  10.0.0.0/16
  10.96.0.0/16
)

for ip in "${IPS[@]}"; do
  firewall-cmd --zone=trusted --add-source="$ip" --permanent
done

firewall-cmd --reload
```

If SELINUX is in enforcing mode, it will probably be easier to manage exceptions through `cockpit`.

On the first control-plane node:

```sh
kubeadm init \
  --apiserver-advertise-address=192.168.1.90 \
  --control-plane-endpoint=192.168.1.99
```

Use kube config from `/etc/kubernbetes/admin.conf` to connect management machine.

### Container networking

From the management machine:

```sh
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "arm64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}
shasum -a 256 -c cilium-darwin-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-darwin-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}

cilium install
```

Remove any taints from the first control plane:

```sh
kubectl taint nodes <node-name> node-role.kubernetes.io/control-plane:NoSchedule-
```

### Secondary node install

From the first node compress the certs and copy over to other nodes.
Possibly another way to do this with `--upload-certs` param in `kubeadm`.

```sh
dnf install tar -y
cd /etc/kubernetes/pki
tar -czf kubernetes-pki.tar.gz ca.* sa.* front-proxy-ca.* etcd/ca.*
scp kubernetes-pki.tar.gz miles@dusty:/tmp
scp kubernetes-pki.tar.gz miles@ned:/tmp
rm -f kubernetes-pki.tar.gz
```

From each of the other nodes extract the certs

```sh
dnf install tar -y
mkdir -p /etc/kubernetes/pki
tar -xzf /tmp/kubernetes-pki.tar.gz -C /etc/kubernetes/pki && \
rm -f /tmp/kubernetes-pki.tar.gz
```

Join the other nodes to the cluster using output obtained from `kubeadm init`
on the first node or use `kubeadm token create --print-join-command`.

```sh
kubeadm join 192.168.1.99:6443 \
  --token <insert-token-here> \
	--discovery-token-ca-cert-hash <insert-cert-hash-here> \
	--control-plane
```

Run `cilium hubble enable --ui` and forward `hubble-relay` port 4245 to management machine

We can now check core networking is all working with `cilium connectivity test`

If we're all 🙂 then clean up the test pods `kubectl delete namespace cilium-test-1`

### Tailscale operator

Use Tailscale admin website to generate oauth credentials and then deploy the
Tailscale operator:

```sh
helm repo add tailscale https://pkgs.tailscale.com/helmcharts

help repo update

helm upgrade \
  --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId="<OAauth client ID>" \
  --set-string oauth.clientSecret="<OAuth client secret>" \
  --wait
```

### Longhorn Prerequisites

Additionally packages are required for the Longhorn storage driver

```sh
apt install -y open-iscsi nfs-common

dnf install -y iscsi-initiator-utils nfs-utils
```

### Bootstrapping with ArgoCD for app deployment

From `bootstrap` folder, run `install.sh` and get ready to sit back and drink 🍻
