# Homelab Kubernetes Platform

A modular, production-style Kubernetes homelab stack with GitOps-friendly structure, reverse proxy, load balancer, easy administration, and monitoring. The project uses Kustomize overlays with Helm chart rendering for clean separation of base and environment-specific configuration.

## What this provides

- Reverse proxy and ingress gateway via Traefik
- Load balancer via MetalLB for bare-metal clusters
- Easy administration via Argo CD (GitOps)
- Monitoring stack via Prometheus and Grafana
- Modular configuration using Kustomize bases and overlays
- CI validation and optional CD sync with Argo CD

## Repository structure

- Cluster entrypoint: [clusters/homelab/kustomization.yaml](clusters/homelab/kustomization.yaml)
- Argo CD: [infra/argocd/overlays/homelab](infra/argocd/overlays/homelab)
- MetalLB: [infra/metallb/overlays/homelab](infra/metallb/overlays/homelab)
- Traefik: [infra/traefik/overlays/homelab](infra/traefik/overlays/homelab)
- Monitoring: [infra/monitoring/overlays/homelab](infra/monitoring/overlays/homelab)
- Apps namespace: [apps/overlays/homelab](apps/overlays/homelab)

## Prerequisites

- A running Kubernetes cluster for your homelab
- kubectl configured for the cluster
- kustomize v5+ with Helm support
- Helm installed locally (for troubleshooting and manual chart inspections)

## Configure the homelab overlay

1. Update the MetalLB IP pool to match your LAN range in [infra/metallb/overlays/homelab/ipaddresspool.yaml](infra/metallb/overlays/homelab/ipaddresspool.yaml).
2. Update Grafana admin password in [infra/monitoring/overlays/homelab/values.yaml](infra/monitoring/overlays/homelab/values.yaml).
3. Adjust Traefik settings in [infra/traefik/overlays/homelab/values.yaml](infra/traefik/overlays/homelab/values.yaml).
4. Review Argo CD settings in [infra/argocd/overlays/homelab/values.yaml](infra/argocd/overlays/homelab/values.yaml).

## kind on localhost (MetalLB access)

MetalLB works on kind only if the IP pool is inside the kind Docker network and your host can route to that subnet.

### 1) Choose a pool inside the kind network

Find the kind network subnet:

```
docker network inspect kind --format '{{(index .IPAM.Config 0).Subnet}}'
```

Pick an unused range inside that subnet and set it in
[infra/metallb/overlays/homelab/ipaddresspool.yaml](infra/metallb/overlays/homelab/ipaddresspool.yaml).

### 2) Add a host route (Linux)

Route the kind subnet via the kind bridge so your host can reach LoadBalancer IPs:

```
sudo ip route add <KIND_SUBNET> dev br-$(docker network inspect -f '{{.Id}}' kind | cut -c1-12)
```

Replace `<KIND_SUBNET>` with the subnet from step 1 (for example `10.89.1.0/24`).

### 3) Optional: port-mapping instead of routing

If you prefer local ports instead of routing, create the kind cluster with port mappings and use a `NodePort` or ingress controller. Example kind config:

```
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
      - containerPort: 443
        hostPort: 8443
```

Then reach your services at `http://localhost:8080` or `https://localhost:8443`.

## Deploy the stack

Apply the full stack with Kustomize (server-side apply avoids CRD annotation size limits). If your cluster already has resources created with client-side apply, use force conflicts to take ownership:

```
kustomize build --enable-helm clusters/homelab | kubectl apply --server-side --force-conflicts -f -
```

Optional helper script:

```
./scripts/apply-homelab.sh
```

## Accessing services

- MetalLB allocates LoadBalancer IPs for Traefik, Argo CD, and Grafana.
- Use `kubectl get svc -A` to locate assigned IP addresses.
- If you cannot reach a LoadBalancer IP on kind, use port-forwarding. Example for Grafana:

```
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Then open `http://localhost:3000`.

## GitOps with Argo CD

Argo CD is installed as part of the stack. To make this repo the source of truth:

1. Create an Argo CD Application pointing to this repository and path `clusters/homelab`.
2. Enable auto-sync and prune in the Argo CD UI.

A minimal Application example (replace values for your repo):

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homelab
  namespace: argocd
spec:
  project: default
  source:
    repoURL: <your-repo-url>
    targetRevision: main
    path: clusters/homelab
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## CI/CD

### CI: manifest validation

The workflow in [.github/workflows/ci.yaml](.github/workflows/ci.yaml) builds the full stack and runs schema validation.

### CD: Argo CD sync

The workflow in [.github/workflows/cd-argocd-sync.yaml](.github/workflows/cd-argocd-sync.yaml) optionally triggers a sync with Argo CD. Add the following secrets:

- `ARGOCD_SERVER`
- `ARGOCD_AUTH_TOKEN`
- `ARGOCD_APP`

If you prefer pure GitOps, you can disable this workflow and let Argo CD pull changes from the repo.

## Customization tips

- Add more overlays under [clusters](clusters) for additional environments.
- Put application manifests under [apps/base](apps/base) and create overlays per environment.
- Pin chart versions in the overlay `kustomization.yaml` files under [infra](infra).

## Troubleshooting

- Validate manifests locally:
  ```
  kustomize build --enable-helm clusters/homelab
  ```
- Check MetalLB speaker logs if LoadBalancer IPs are not assigned.
- Confirm Traefik service type is LoadBalancer in [infra/traefik/overlays/homelab/values.yaml](infra/traefik/overlays/homelab/values.yaml).

## Security notes

- Replace `grafana.adminPassword` in [infra/monitoring/overlays/homelab/values.yaml](infra/monitoring/overlays/homelab/values.yaml).
- Use TLS and proper authentication before exposing services outside your LAN.
