#!/usr/bin/env zsh
set -euo pipefail

source .env

brew install helm kubernetes-cli

helm repo add cilium https://helm.cilium.io/
helm repo add tailscale https://pkgs.tailscale.com/helmcharts

helm repo update

helm upgrade \
  --install \
  cilium \
  cilium/cilium \
  --version 1.18.2 \
  --namespace kube-system \
  --wait

helm upgrade \
  --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId="$TAILSCALE_CLIENT_ID" \
  --set-string oauth.clientSecret="$TAILSCALE_CLIENT_SECRET" \
  --set-string operatorConfig.image.repository="quay.io/drewmullen/tailscale" \
  --set-string operatorConfig.image.tag="latest" \
  --wait

kubectl apply -k argocd/
