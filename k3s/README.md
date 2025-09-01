# Installing k3s

This is a casual guide for installing a 5-node HA k3s cluster.

The following is assumed:

- `haproxy` configured and running at 192.168.1.99 as load balancer
- 3x OpenSUSE Linux machines running on consecutive IPs from 192.168.1.90, I've named them `lucky`, `dusty`, `ned`.

## Initialise nodes

Add firewall rules if needed, e.g.

```sh
IPS=(
  192.168.1.0/24
  10.42.0.0/16
  10.43.0.0/16
)

for ip in "${IPS[@]}"; do
  firewall-cmd --zone=trusted --add-source="$ip" --permanent
done

firewall-cmd --reload
```

Switch SELINUX to permissive mode as the RPM is missing/broken on OpenSUSE at time of writing (check `/etc/selinux/config`).

On the first control-plane node:

```sh
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_SKIP_SELINUX_RPM=true \
  INSTALL_K3S_EXEC="server --cluster-init --tls-san 192.168.1.99" \
  sh -s - server \
  --tls-san 192.168.1.99
```

Get the server token for joining the secondary nodes

```sh
cat /var/lib/rancher/k3s/server/node-token
```

...and the kube config to apply to ~/.kube/config on management devices

```sh
cat /etc/rancher/k3s/k3s.yaml
```

## Install the HA control plane nodes

```sh
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_SKIP_SELINUX_RPM=true \
  INSTALL_K3S_EXEC="server --tls-san 192.168.1.99" \
  sh -s - server \
  --token <token-here> \
  --server https://192.168.1.99:6443
```

## Install any worker nodes

Not using them in my case as the control-planes are also running workloads, but for prosperity:

```sh
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_SKIP_SELINUX_RPM=true \
  sh -s - agent \
  --token <token-here> \
  --server https://192.168.1.99:6443"
```
