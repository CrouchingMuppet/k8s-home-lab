# Deploying OpenShift (OKD) via Ansible

Download pull secret: https://console.redhat.com/openshift/install/pull-secret

```sh
mise trust

ansible-galaxy install -r requirements.yml

# Create OKD infra within Proxmox
ansible-playbook create-pve.yml
# Remove OKD infra from Proxmox
ansible-playbook destroy-pve.yml

# Create OKD infra within Unraid
ansible-playbook create-unraid.yml
# Remove OKD infra from Unraid
ansible-playbook destroy-unraid.yml
```
