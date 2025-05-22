#!/usr/bin/env zsh

kubectl create namespace argocd
kubectl apply -k argocd/
