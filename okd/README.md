# Installing OpenShift (OKD)

## Virtual machines

OpenShift is heavy on resources compared to pure k8s.  

Control plane machines seem to require a minimum 6 vCPUs and 16 GB RAM, otherwise critical pods will not be assigned and bootstapping will stall.

## Creating ignition configuration

Copy `install-config.yaml` to a folder and add pull secret.

Get the installer (assuming for mac):

```sh
curl -LO https://github.com/okd-project/okd/releases/download/4.19.0-okd-scos.2/openshift-install-mac-arm64-4.19.0-okd-scos.2.tar.gz
tar -xvf openshift-install-mac-arm64-4.19.0-okd-scos.2.tar.gz
sudo mv openshift-install /usr/local/bin
```

Create the manifests and ignition files:

```sh
openshift-install create manifests
openshift-install create ignition-configs
```

Move the `.ign` files to a static file server (assuming http://files.zero).

Determine and download the coreos `.iso` for the installer version above:

```sh
openshift-install coreos print-stream-json | grep '\.x86_64.iso[^.]'
```

## DNS and HAproxy

Initial bootstrapping requires kubernetes API `:6443` and machineconfig `:22623` forwarded to the bootstrap machine. Bootstrap machine can be removed once complete.

