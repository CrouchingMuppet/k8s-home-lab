# Installing kubernetes

This is a casual guide for installing a 3-node HA kubernetes cluster.

The following is assumed:

- `haproxy` configured and running at 192.168.1.99 as load balancer
- 3 other Alma Linux based machines running on the same consecutive IPs from 192.168.1.90, I've named them `lucky`, `dusty` and `ned`.

## Install packages on all nodes

```zsh
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

dnf install -y cri-o kubelet kubeadm

systemctl enable --now crio.service && \
systemctl enable --now kubelet.service
```

## Initialise nodes

Add firewall rules if needed, e.g.

```sh
firewall-cmd --permanent --zone=trusted --add-source=192.168.1.99 && \
firewall-cmd --permanent --zone=trusted --add-source=192.168.1.90 && \
firewall-cmd --permanent --zone=trusted --add-source=192.168.1.91 && \
firewall-cmd --permanent --zone=trusted --add-source=192.168.1.92 && \
firewall-cmd --permanent --zone=trusted --add-source=10.0.0.0/16 && \
firewall-cmd --permanent --zone=trusted --add-source=10.96.0.0/12 && \
firewall-cmd --reload
```

If SELINUX is in enforcing mode, it will probably be easier to manage exceptions through `cockpit`.

On the first control-plane node:

```zsh
kubeadm init \
  --apiserver-advertise-address=192.168.1.90 \
  --control-plane-endpoint=192.168.1.99
```

Use kube config from `/etc/kubernbetes/admin.conf` to connect management machine.

### Container networking

From the management machine:

```zsh
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

```zsh
kubectl taint nodes <node-name> node-role.kubernetes.io/control-plane:NoSchedule-
```

### Secondary node install

From the first node compress the certs and copy over to other nodes.
Possibly another way to do this with `--upload-certs` param in `kubeadm`.

```zsh
dnf install tar -y
cd /etc/kubernetes/pki
tar -czf kubernetes-pki.tar.gz ca.* sa.* front-proxy-ca.* etcd/ca.*
scp kubernetes-pki.tar.gz miles@dusty:/tmp
scp kubernetes-pki.tar.gz miles@ned:/tmp
rm -f kubernetes-pki.tar.gz
```

From each of the other nodes extract the certs

```zsh
dnf install tar -y
mkdir -p /etc/kubernetes/pki
tar -xzf /tmp/kubernetes-pki.tar.gz -C /etc/kubernetes/pki && \
rm -f /tmp/kubernetes-pki.tar.gz
```

Join the other nodes to the cluster using output obtained from `kubeadm init`
on the first node or use `kubeadm token create --print-join-command`.

```zsh
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

```zsh
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

### Bootstrapping with ArgoCD for bootstrapping and app deployment

From `bootstrap` folder, run `install.sh` and get ready to sit back and drink 🍻
