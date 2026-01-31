#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

kustomize build --enable-helm "$ROOT_DIR/clusters/homelab" | kubectl apply --server-side -f -