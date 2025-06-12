#!/usr/bin/env zsh

echo "Tailscale client id?"
read TAILSCALE_CLIENT_ID

echo "Tailscale secret?"
read TAILSCALE_SECRET

helm repo add tailscale https://pkgs.tailscale.com/helmcharts

helm repo update

helm upgrade \
  --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId="$TAILSCALE_CLIENT_ID" \
  --set-string oauth.clientSecret="$TAILSCALE_SECRET" \
  --set-string operatorConfig.image.repository="quay.io/drewmullen/tailscale" \
  --set-string operatorConfig.image.tag="latest" \
  --wait

kubectl create namespace argocd
kubectl apply -k argocd/
