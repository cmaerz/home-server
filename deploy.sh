#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Pulling latest changes..."
git pull || echo "Warning: git pull failed (no network?), continuing with local files..."

echo "Deploying homelab to k3s..."

# Namespace first
kubectl apply -f k3s/namespace.yaml

# Storage
kubectl apply -f k3s/storage/

# DNS
kubectl apply -f k3s/dns/

# Apps
kubectl apply -f k3s/emby/
kubectl apply -f k3s/jdownloader/
kubectl apply -f k3s/sonarr/
kubectl apply -f k3s/radarr/
kubectl apply -f k3s/dashboard/
kubectl apply -f k3s/samba/

# Ingress
kubectl apply -f k3s/ingress.yaml

echo ""
echo "Waiting for pods..."
kubectl wait --for=condition=Ready pods --all -n homelab --timeout=120s || true

echo ""
kubectl get pods -n homelab
