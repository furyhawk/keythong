#!/usr/bin/env bash
set -euo pipefail

# Persist inotify limits for Prometheus config reloader

CONF_FILE="/etc/sysctl.d/99-inotify.conf"

sudo tee "$CONF_FILE" >/dev/null <<'EOF'
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=8192
EOF

sudo sysctl --system
