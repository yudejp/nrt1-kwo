#!/usr/bin/env bash
set -euo pipefail

# DB logical-dump PVCs and reconstructible cache PVCs excluded from raw PVC snapshot backup
EXCLUDE_PVCS=(
  # PostgreSQL (backed up via postgres-backup-daily logical dump)
  "default/pgdata-za-pg-16-0"
  "default/pgdata-za-pg-16-1"
  # MongoDB ReplicaSet (backed up via mongodb-backup-daily logical dump)
  "mongodb/data-volume-mongodb-rs-0"
  "mongodb/data-volume-mongodb-rs-1"
  "mongodb/data-volume-mongodb-rs-2"
  "mongodb/logs-volume-mongodb-rs-0"
  "mongodb/logs-volume-mongodb-rs-1"
  "mongodb/logs-volume-mongodb-rs-2"
  # Reconstructible cache / media index PVCs
  "default/meilisearch"
  "default/navidrome-data"
  "ot-operators/redis-redis-0"
)

for entry in "${EXCLUDE_PVCS[@]}"; do
  ns="${entry%%/*}"
  pvc="${entry##*/}"
  if kubectl get pvc "$pvc" -n "$ns" >/dev/null 2>&1; then
    kubectl label pvc "$pvc" -n "$ns" backup.yude.jp/exclude=true --overwrite
  else
    echo "WARN: PVC ${ns}/${pvc} not found, skipping" >&2
  fi
done

echo ""
echo "=== Active Longhorn PVCs scheduled for backup ==="
kubectl get pvc -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"|"}{.spec.storageClassName}{"|"}{.status.capacity.storage}{"|"}{.metadata.labels.backup\.yude\.jp/exclude}{"\n"}{end}' \
  | awk -F'|' '($3=="longhorn" || $3=="longhorn-static") && $5!="true" {printf "%-18s %-36s %s\n", $1, $2, $4}' \
  | sort
