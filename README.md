# K8s Home Lab

Herein are the manifests I use to deploy components of my home lab
setup using ArgoCD.

## Installing kubernetes

A guide once lived here to help create kubernetes infra which has been
automated with Ansible and can be found
[here](https://github.com/CrouchingMuppet/k8s-4-unraid-pve)

## Bootstrapping with ArgoCD for app deployment

1. Create git-ignored `.env` file with `TAILSCALE_CLIENT_ID` and `TAILSCALE_CLIENT_SECRET`.
1. Run `install.sh` and get ready to sit back and drink 🍻
