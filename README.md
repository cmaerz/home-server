# Home Server (k3s)

Kubernetes-based home server running on k3s with Traefik ingress.

## Architecture

```
Clients → CoreDNS (:53) → *.sandharlanden.maerz → Node IP
                       → All other queries → PiHole (:5353) → Upstream (ad-blocked)
```

## Services

| Service | Description | Access |
|---------|-------------|--------|
| CoreDNS | Internal DNS | Port 53 (primary DNS for Unifi) |
| PiHole | Ad-blocker | `http://pihole.sandharlanden.maerz` or `:30080` |
| Emby | Media server | `http://emby.sandharlanden.maerz` or `:30096` |
| JDownloader | Download manager | `http://jdownloader.sandharlanden.maerz` or `:30580` |

## Prerequisites

- Linux server (tested on Ubuntu/Debian)
- k3s installed: `curl -sfL https://get.k3s.io | sh -`
- `kubectl` configured (k3s does this automatically)

## Directory Structure

```
k3s/
├── namespace.yaml           # homelab namespace
├── storage/
│   └── local-storage.yaml   # PersistentVolume configs
├── coredns/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml       # UPDATE NODE_IP!
├── pihole/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── secret.yaml          # CHANGE PASSWORD!
│   └── pvc.yaml
├── emby/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── pvc.yaml
├── jdownloader/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── pvc.yaml
└── ingress.yaml             # Traefik IngressRoutes
```

## Quick Start

### 1. Create Data Directories

```bash
sudo mkdir -p /var/lib/homelab/{emby,jdownloader,pihole/{etc,dnsmasq}}
sudo mkdir -p /data/media
sudo chown -R 1000:1000 /var/lib/homelab /data/media
```

### 2. Configure Node IP and Passwords

```bash
# Get your node IP
hostname -I | awk '{print $1}'
```

Edit `k3s/coredns/configmap.yaml` and set `NODE_IP` to your node's IP.

Edit `k3s/pihole/secret.yaml` and change the `WEBPASSWORD` value.

### 3. Deploy All Services

```bash
# Apply namespace first
kubectl apply -f k3s/namespace.yaml

# Apply storage configuration
kubectl apply -f k3s/storage/

# Deploy DNS (CoreDNS first, then PiHole)
kubectl apply -f k3s/coredns/
kubectl apply -f k3s/pihole/

# Deploy apps
kubectl apply -f k3s/emby/
kubectl apply -f k3s/jdownloader/

# Apply ingress routes
kubectl apply -f k3s/ingress.yaml
```

Or deploy everything at once:

```bash
kubectl apply -f k3s/namespace.yaml
kubectl apply -f k3s/ --recursive
```

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n homelab

# Check services
kubectl get svc -n homelab

# Check ingress routes
kubectl get ingressroute -n homelab
```

## Unifi Configuration

1. **Unifi Console** → Settings → Networks → (Your Network)
2. **DHCP Name Server**: Set to **Manual**
3. **DNS Server 1**: `<Your k3s node IP>` (CoreDNS on port 53)
4. **DNS Server 2**: `1.1.1.1` (fallback)

That's it! CoreDNS handles `*.sandharlanden.maerz` and forwards everything else to PiHole for ad-blocking.

## Storage Configuration

| Service | Container Path | Host Path |
|---------|---------------|-----------|
| Emby config | `/config` | `/var/lib/homelab/emby` |
| Emby media | `/data/media` | `/data/media` |
| JDownloader config | `/config` | `/var/lib/homelab/jdownloader` |
| JDownloader downloads | `/output` | `/data/media` |
| PiHole config | `/etc/pihole` | `/var/lib/homelab/pihole/etc` |
| PiHole dnsmasq | `/etc/dnsmasq.d` | `/var/lib/homelab/pihole/dnsmasq` |

## Useful Commands

```bash
# View logs
kubectl logs -n homelab deployment/pihole
kubectl logs -n homelab deployment/emby
kubectl logs -n homelab deployment/jdownloader

# Restart a deployment
kubectl rollout restart deployment/emby -n homelab

# Scale down (stop)
kubectl scale deployment/emby --replicas=0 -n homelab

# Scale up (start)
kubectl scale deployment/emby --replicas=1 -n homelab

# Delete everything
kubectl delete -f k3s/ --recursive
kubectl delete namespace homelab
```

## Troubleshooting

### PiHole DNS not responding

PiHole uses `hostNetwork: true` to bind port 53. Verify:
```bash
# Check if port 53 is bound
sudo ss -tulpn | grep :53

# Check pod status
kubectl describe pod -n homelab -l app=pihole
```

### Services not accessible via hostname

1. Verify ingress routes: `kubectl get ingressroute -n homelab`
2. Check Traefik logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=traefik`
3. Add local DNS entries in PiHole or `/etc/hosts`

### Pod stuck in Pending

Check PVC status:
```bash
kubectl get pvc -n homelab
kubectl describe pvc <pvc-name> -n homelab
```

