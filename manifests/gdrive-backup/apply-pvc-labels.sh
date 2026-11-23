#!/usr/bin/env bash
set -euo pipefail

# Opt-in: Longhorn PVCs enabled for daily Google Drive snapshot backup
ENABLE_PVCS=(
  "adguard/adguard-certs"
  "adguard/adguard-conf"
  "adguard/adguard-work"
  "crowdsec/crowdsec-config-pvc"
  "crowdsec/crowdsec-db-pvc"
  "default/gri-gra"
  "default/gri-tra"
  "default/open-webui-data"
  "default/pgadmin-data-pgadmin-0"
  "default/redmine"
  "default/vaultwarden-vaultwarden-release-0"
  "gitea/gitea-data"
  "growi/growi-uploads"
  "misskey-y2e-org/misskey-files"
  "sumire/sumire-data"
  "sumire/sumire-opencode-data"
  "tunwatch/tunwatch"
)

for entry in "${ENABLE_PVCS[@]}"; do
  ns="${entry%%/*}"
  pvc="${entry##*/}"
  if kubectl get pvc "$pvc" -n "$ns" >/dev/null 2>&1; then
    kubectl label pvc "$pvc" -n "$ns" gdrive-backup.k8s.y2e.org/enabled=true --overwrite
  else
    echo "WARN: PVC ${ns}/${pvc} not found, skipping" >&2
  fi
done

echo ""
echo "=== Active Longhorn PVCs enabled for backup (opt-in) ==="
kubectl get pvc -A -l gdrive-backup.k8s.y2e.org/enabled=true \
  -o jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"|"}{.spec.storageClassName}{"|"}{.status.capacity.storage}{"\n"}{end}' \
  | awk -F'|' '($3=="longhorn" || $3=="longhorn-static") {printf "%-18s %-36s %s\n", $1, $2, $4}' \
  | sort
