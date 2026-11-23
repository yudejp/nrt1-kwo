# gdrive-backup

k3s クラスタ上の Longhorn PVC（CSI `VolumeSnapshot` 経由の `.tar.gz`）および PostgreSQL / MongoDB 論理ダンプを、Kubernetes 内 CronJob + `rclone` で Google Drive（`gdrive:k8s-backup/`）へ無暗号・直接読取可能な形式で日次バックアップするマニフェスト群です。

## 構成

| CronJob (`backup-system`) | 実行時刻 (JST) | 対象 | 出力先 (`gdrive:k8s-backup/`) | 保持 |
|---|---|---|---|---|
| `postgres-backup-daily` | 毎日 02:00 | `default/za-pg-16` (`pg_dumpall`) | `db/postgres/za-pg-16-<stamp>.sql.gz` | 最新 7 世代 |
| `mongodb-backup-daily` | 毎日 02:30 | `mongodb/mongodb-rs` (`mongodump --oplog`) | `db/mongodb/mongodb-rs-<stamp>.archive.gz` | 最新 7 世代 |
| `pvc-backup-daily` | 毎日 03:00 | `backup.yude.jp/exclude=true` が無い全 Longhorn PVC | `pvcs/<ns>/<pvc>/<stamp>.tar.gz` | 最新 7 世代 |

### バックアップ対象外（`backup.yude.jp/exclude=true` 付与済み）

- PostgreSQL PVC: `default/pgdata-za-pg-16-{0,1}`（論理ダンプで取得）
- MongoDB PVC: `mongodb/{data,logs}-volume-mongodb-rs-{0,1,2}`（論理ダンプで取得）
- 再構築可能データ: `default/meilisearch`（`manifests/meilisearch/pvc.yaml`）, `default/navidrome-data`（`manifests/navidrome/pvc.yaml`）, `ot-operators/redis-redis-0`

今後新しく作成した Longhorn PVC は **自動的に日次バックアップ対象** になります。除外したい PVC にはマニフェストの `metadata.labels` へ `backup.yude.jp/exclude: "true"` を追加するか、以下を実行してください。

```bash
kubectl label pvc <pvc-name> -n <namespace> backup.yude.jp/exclude=true --overwrite
```

---

## 初回セットアップ（Google Drive OAuth Secret 作成）

> **注意**: 平文の `rclone.conf` や `secret.yaml` は Git にコミットしないでください（SealedSecrets で管理する場合はリポジトリルートの [SECRETS.md](../../SECRETS.md) を参照してください）。

1. Google Cloud Console で OAuth クライアント（種類: **デスクトップアプリ**、例: `k8s-pvc-backup`）を作成する。
   - Google Drive API を有効化し、OAuth 同意画面のスコープに `https://www.googleapis.com/auth/drive.file` のみを追加。
   - **公開ステータスを「本番環境（In production）」** にする（「テスト中」だと 7 日でトークン失効）。
2. 一時ファイルでヘッドレス `rclone config` を実行し、ブラウザのある手元 PC で `rclone authorize` を完了させる。

```bash
TMP_CONF="$(mktemp)"
chmod 600 "$TMP_CONF"
rclone config --config "$TMP_CONF"
```

入力例:
- `n` (New remote) → name: **`gdrive`**
- Storage: **`drive`**
- `client_id` / `client_secret`: 1 で作成したもの
- `scope`: **`drive.file`**
- `service_account_file`: 空
- `Edit advanced config`: `n`
- `Use auto config?`: **`n`** → 表示された `rclone authorize ...` を手元 PC で実行しトークンを貼り付け
- `Shared Drive`: `n`

3. 作成した `rclone.conf` を `backup-system` Namespace の Secret として登録し、ローカル一時ファイルを削除する。

```bash
# 疎通確認（k8s-backup フォルダを rclone 経由で作成）
rclone --config "$TMP_CONF" mkdir gdrive:k8s-backup
rclone --config "$TMP_CONF" lsd gdrive:k8s-backup

# Secret 投入（SealedSecret 化する場合は SECRETS.md に従う）
kubectl create secret generic rclone-config \
  -n backup-system \
  --from-file=rclone.conf="$TMP_CONF" \
  --dry-run=client -o yaml | kubectl apply -f -

# 一時ファイル削除
shred -u "$TMP_CONF" 2>/dev/null || rm -f "$TMP_CONF"
```

---

## マニフェストの適用と動作確認

```bash
# kustomize ビルド検証 & 適用
kubectl kustomize manifests/gdrive-backup/ > /dev/null
kubectl apply -k manifests/gdrive-backup/

# オペレータ管理 PVC を含む除外対象 PVC にラベルを付与
bash manifests/gdrive-backup/apply-pvc-labels.sh

# 手動テスト実行（Secret 投入後）
kubectl create job -n backup-system --from=cronjob/postgres-backup-daily manual-pg-1
kubectl create job -n backup-system --from=cronjob/mongodb-backup-daily manual-mg-1
kubectl create job -n backup-system --from=cronjob/pvc-backup-daily manual-pvc-1

# ログ確認
kubectl logs -n backup-system -f job/manual-pg-1
kubectl logs -n backup-system -f job/manual-mg-1
kubectl logs -n backup-system -f job/manual-pvc-1
```

---

## リストア手順

### 1. PVC から単一ファイルを取り出す（PC / サーバ上で直接展開）

Google Drive Web UI から対象 `.tar.gz` をダウンロードするか、`rclone copy` で取得して展開します。

```bash
tar -tzf 2026-11-23_030000.tar.gz | head
tar -xzf 2026-11-23_030000.tar.gz -C /tmp/restore/
```

### 2. PVC 丸ごと復元する

1. 対象アプリの Deployment / StatefulSet を `replicas=0` にスケールダウン。
2. 復元先 PVC をマウントした一時 Pod を起動し、`--numeric-owner` 付きで展開：

```bash
kubectl cp 2026-11-23_030000.tar.gz <ns>/<restore-pod>:/tmp/backup.tar.gz
kubectl exec -n <ns> <restore-pod> -- sh -c 'rm -rf /data/* /data/.[!.]* /data/..?* && tar --numeric-owner -xzf /tmp/backup.tar.gz -C /data'
```

3. 一時 Pod を削除し、アプリを元のレプリカ数へ戻す。

### 3. PostgreSQL (`za-pg-16`) の復元

```bash
gunzip -c za-pg-16-2026-11-23_020000.sql.gz | kubectl exec -i -n default za-pg-16-0 -- psql -U postgres
```

### 4. MongoDB (`mongodb-rs`) の復元

```bash
kubectl exec -i -n mongodb mongodb-rs-0 -c mongod -- \
  mongorestore --uri="mongodb://<user>:<pass>@localhost:27017/?authSource=admin" \
  --archive --gzip --oplogReplay --drop \
  < mongodb-rs-2026-11-23_023000.archive.gz
```
