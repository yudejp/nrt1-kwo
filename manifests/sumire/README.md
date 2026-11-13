# sumire / すみれ

Misskey の会話ボットです。全ユーザー・全スレッドで OpenCode の永続セッションを1つ共有します。ソースは [yude/sumire](https://github.com/yude/sumire) の `manifests/sumire/` です。

Deployment 1 Pod / 2コンテナ＋初期化用コンテナ、独立した PVC 2個で構成します。Go だけに Misskey トークンを渡し、OpenCode には read / glob / grep だけを許可します。Service / Ingress は不要です。

## 必要な Secret

設定するのは `sumire-misskey` の `token` だけです。GHCR イメージは public のため imagePullSecrets は不要です。ソースリポジトリは private のままです。

OpenCode V2 は HTTP 認証を要求しますが、その内部用パスワードは init container が起動時に自動生成します。メモリ上の emptyDir に保存して両コンテナへ読み取り専用で共有し、Pod 再作成時に更新します。Vault や Kubernetes Secret への登録・手入力は不要です。

## Vault から封印する

新規作成時は `vault.example.yml` の `secret_manifest` を参考に Vault エディタで token を設定します。既存の `secret_manifests` に3件入った Vault も変更せず使えます。旧 sumire-opencode-auth と ghcr-pull は無視し、sumire-misskey だけを封印します。

```bash
# Vault を新規作成する場合
ansible-vault create manifests/sumire/vault.yml --ask-vault-pass

# 既存 Vault の token を使って封印する場合
ANSIBLE_BECOME_ASK_PASS=false ANSIBLE_LOCAL_TEMP=/tmp/sumire-ansible ANSIBLE_REMOTE_TEMP=/tmp/sumire-ansible-remote ansible-playbook -i localhost, -c local playbooks/seal-sumire-secret.yaml --ask-vault-pass

kubectl kustomize manifests/sumire/
```

`--ask-vault-pass` の代わりに `--vault-password-file /secure/path/to/vault-password` も使えます。BECOME password を抑止する環境変数は省略しないでください。

クラスタの共通公開証明書 `manifests/cloudflare-tunnel-controller/pub-cert.pem` で封印します。成功すると sealedsecret.yaml を生成し、Kustomize の resources に登録します。空の token、平文 Vault、namespace 違いは拒否し、値をログに出しません。既存の単一 Secret 用 playbook は変更していません。

## 適用と確認

MISSKEY_URL と封印した token を用意した後で実行します。既定値の DRY_RUN=true では Misskey に投稿しません。

```bash
kubectl diff -k manifests/sumire/
kubectl apply -k manifests/sumire/
kubectl -n sumire get sealedsecret sumire-misskey
kubectl -n sumire rollout status deployment/sumire
kubectl -n sumire logs deployment/sumire -c sumire
kubectl -n sumire exec deployment/sumire -c sumire -- sumire status
```

Vault と Secret の保管方針は [SECRETS.md](../../SECRETS.md) を参照してください。

## 配布確認（2026-11-13）

sumire Namespace に適用済みです。Deployment は Available 1/1、Pod は2/2 Running、healthz / readyz は HTTP 200 を確認しました。SealedSecret は同期済み、PVC 2個は Longhorn 上で Bound・healthy です。PVC の storageClassName は longhorn に固定しています。

専用 Misskey アカウントの Bot フラグを有効化し、初回適用時は DRY_RUN=true で起動しました。この時点では実投稿・実メンションへの返答は未検証でした。適用時の証跡と停止手順はローカルの配布記録に保存しています。

## 実投稿の有効化（2026-11-13）

運用側の DRY_RUN を false に変更して適用済みです。新しい Pod は2/2 Running、再起動0回で、共有セッションを維持しています。今後届く人間のリプライ・メンションに対して、生成した返答を元ノートへの返信として投稿します。通知確認は15秒間隔です。過去の dry_run ジョブを再投稿する処理はありません。

停止する場合は DRY_RUN=true を反映してください。投稿状態の DB や PVC は巻き戻さず保持します。

## 実リプライへの返信確認（2026-11-14）

ユーザーが送った[リプライ](https://misskey.y2e.org/notes/atj18pgzhx)を受信し、[sumire の返信](https://misskey.y2e.org/notes/atj18w75dz)が実際に投稿されました。06:07:51 から 06:08:00（JST）まで約8.7秒。Misskey API で返信先 ID、投稿者 sumire、空でない本文を照合し、アプリの reply posted ログとも一致しました。

続く2件にも返信し、[直近の返答](https://misskey.y2e.org/notes/atj1ec86i8)を含む3件の投稿を API で確認しました。ジョブは posted が3件、未解決は0件。共有セッションを維持し、Pod は2/2 Running・再起動0回です。本文や認証情報は記録に含めていません。
