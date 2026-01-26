#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Deploying homelab to k3s..."

# Namespace first
kubectl apply -f k3s/namespace.yaml

# Storage
kubectl apply -f k3s/storage/

# DNS stack (order matters)
kubectl apply -f k3s/coredns/
kubectl apply -f k3s/pihole/

# Apps
kubectl apply -f k3s/emby/
kubectl apply -f k3s/jdownloader/

# Ingress
kubectl apply -f k3s/ingress.yaml

echo ""
echo "Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n homelab --timeout=120s || true

echo ""
kubectl get pods -n homelab
