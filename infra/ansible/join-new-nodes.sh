#!/usr/bin/env bash
# After a merged PR created new EC2 nodes: refresh inventory, install k3s on them, show the result.
set -euo pipefail
cd "$(dirname "$0")"
./refresh-inventory.sh
ansible all -m ping
ansible-playbook site.yml
KUBECONFIG="$PWD/kubeconfig" kubectl get nodes -L region
