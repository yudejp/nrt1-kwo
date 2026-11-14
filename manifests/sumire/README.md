# sumire / すみれ

Misskey の会話ボットです。全ユーザー・全スレッドで OpenCode の永続セッションを1つ共有します。ソースは [yude/sumire](https://github.com/yude/sumire) の `manifests/sumire/` です。

Deployment 1 Pod / 2コンテナ＋初期化用コンテナ、独立した PVC 2個で構成します。Go だけに Misskey トークンを渡し、OpenCode には read / glob / grep だけを許可します。Service / Ingress は不要です。

## 必要な Secret

Misskey 用は `sumire-misskey` の `token`、Groq Free 用は `sumire-groq` の `api-key` です。GHCR イメージは public のため imagePullSecrets は不要です。ソースリポジトリは private のままです。

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

## 日次コメントと手動実行

DAILY_ENABLED=true、DAILY_AT=20:00（日本時間）、DAILY_MIN_NOTES=3、DAILY_MIN_AUTHORS=2 を設定しています。直近24時間の local timeline に対象3件以上・2人以上がいる場合にコメントを1件投稿します。Bot・自身・リノート・返信・本文なし・CW付き・連合なし・public 以外の投稿は除外し、投稿不足時はモデルを呼ばず見送ります。取得上限は500件、モデルに渡す本文は最新30件・各600 UTF-16単位までです。投稿は public / localOnly=false（連合あり）の単独ノートです。

```bash
# 投稿なしのテスト。当日分を消費せず、生成した本文をログに出す
kubectl -n sumire exec deployment/sumire -c sumire -- sumire daily --preview
# 当日分を手動で実行。条件・DRY_RUN を守り、当日の重複実行を防ぐ
kubectl -n sumire exec deployment/sumire -c sumire -- sumire daily
# 受付は非同期。daily_runs の job_id/state/post_id とログで結果を確認
kubectl -n sumire exec deployment/sumire -c sumire -- sumire status
kubectl -n sumire logs deployment/sumire -c sumire --tail=100
```

手動 HTTP API は Pod 内の 127.0.0.1:8081 だけに待ち受けます。Service / Ingress・新たな Secret は不要です。通常実行・見送りは日付で永続化し、再起動でも重複させません。20:00以降に復旧した場合は当日分を処理し、前日までの未投稿分は投稿しません。タイムライン取得失敗は日付を消費せず再試行します。

通常の返信は conversation received / reply posted の text に受信・投稿本文を出し、note_id で対応付けられます。プレビューと dry run も本文を記録します。トークン・内部 reasoning は記録しません。

耐障害性として、投稿 API の待機中も他の会話を処理できるキュー選択、OpenCode の読み取りだけの再試行、生成結果不明時の readiness=503、DB 保存失敗時も投稿 ID をログで追える処理を追加しています。

OpenCode は native sidecar（initContainers の restartPolicy: Always）として起動し、Go の終了処理後に停止します。対象は Kubernetes 1.33以降です（実クラスタは v1.35.4）。

## 日次機能の配布検証（2026-11-14）

GitHub Actions 43512380381 の全ジョブ成功後に配布しました。停止中に Go / OpenCode 両 DB をバックアップし、integrity_check=ok を確認。49件・6人の LTL でプレビュー（実投稿なし）が成功し、通常実行で [当日分のコメント](https://misskey.y2e.org/notes/atj2l5vcp3)の投稿を確認しました。本文はアプリログと一致しています。

続く手動実行と Pod 再起動でも同じ投稿 ID を返し、追加投稿はありません。Go の正常終了と native sidecar の停止、共有セッション・投稿状態の維持を確認し、未解決ジョブ0、healthz / readyz 成功、Kustomize との差分なしです。

初回テスト投稿は当時の設定で連合なしでした。ユーザー指示により、次回以降は連合ありに変更して配布済みです。サーバー v2026.11.0 には投稿済みノートの編集 API がなく、既存ノートは変更していません。2026-11-14 の日次枠はテストで実行済みのため、同日の20:00には追加投稿しません。

連合ありの版は CI 43514223412（c6ad801）で全ジョブ成功し、両 public イメージの digest を固定して反映済みです。更新後は連合なしの元ノートを除外した44件・5人でプレビューが dry_run まで成功しました。共有セッション・当日分の投稿状態を維持し、未解決ジョブは0です。

## タイムゾーン・無料枠の障害対応（2026-11-14）

両コンテナを Asia/Tokyo に設定し、小型の opencode/flint-40b-free に変更して反映済みです。入力・出力・キャッシュ価格がすべて0であることを確認して使用します。既存の共有セッションは公式 API でモデル選択だけを変更し、会話履歴は保持します。

09:58:28（JST）の生成は provider.free-limit / HTTP 429 で失敗しました。提供元が示す再試行可能時刻は11/15 09:07頃（JST）です。確定した失敗を回収する際に終了してしまう不具合を修正し、generation_failed として保持します。generation_cooldown の期限まで後続の生成を待機し、通知の受信・本文ログは続けます。失敗した入力を自動再投入せず、後続キューは期限後に処理します。

```bash
kubectl -n sumire exec deployment/sumire -c sumire -- sumire status
kubectl -n sumire exec deployment/sumire -c sumire -- date
kubectl -n sumire exec deployment/sumire -c opencode -- date
```

最終的なモデルは Flint 40B Free です。30日保持・モデル改善利用の可能性がある条件について利用者の明示的な了承を得ました。共有履歴を維持し、無料枠の待機時刻も引き継ぎます。

修正版は CI 43540375486（e72b764）で全ジョブ成功し、同じコードと Docker 設定の公開イメージを digest 固定しています。date=JST+0900 とログの +09:00 表示、共有履歴・投稿済み15件・失敗1件の保持、Go の再起動後も待機期限が変わらないことを確認しました。障害時の両 DB は停止中にバックアップし、integrity_check=ok でした。

## Groq Free のモデルプール

LLM_MODEL=opencode/flint-40b-free を優先し、LLM_FALLBACK_MODELS=groq/openai/gpt-oss-20b に切り替えます。既存 Groq キーが Free プランであることを利用者に確認し、GROQ_FREE_TIER_CONFIRMED=true としています。Groq のカタログ単価は0でないためアカウントが Free であることが必要です。このアカウントを Developer プランへ変更しないでください。キーは OpenCode だけに渡します。

Vault を作成・編集する場合は vault-groq.example.yml の groq_secret_manifest を使います。暗号化済み vault-groq.yml から封印するコマンドは次の通りです。既存 Misskey Vault は変更しません。

```bash
ANSIBLE_BECOME_ASK_PASS=false ANSIBLE_LOCAL_TEMP=/tmp/sumire-ansible ANSIBLE_REMOTE_TEMP=/tmp/sumire-ansible-remote ansible-playbook -i localhost, -c local playbooks/seal-sumire-groq-secret.yaml --ask-vault-pass
kubectl kustomize manifests/sumire/ >/dev/null
kubectl apply -k manifests/sumire/
kubectl -n sumire rollout status deployment/sumire
kubectl -n sumire exec deployment/sumire -c sumire -- sumire status
```

OpenCode の既存待機期限は OpenCode のみに適用して保持します。新しい待機は provider_cooldowns として DB に保存し、両方が上限ならキューで待ちます。CLI の公式 plugin quota-pool.mjs は429の内部再試行を止め、Go のキューに制御を返します。生成前の確定429だけ別の入力 ID で再試行し、通信切断・途中出力などの不明な結果は自動再送しません。共有セッションと履歴、投稿の重複防止は維持します。既存 generation_failed は再投入しません。

Groq は入力6000・出力1000・コンテキスト7000を上限に同じ選択モデルで会話を要約し、最近1500トークンを保持します。要約と通常の返答を合計して上限になる場合も待機します。タイトルの自動生成は無効です。

切戻しは入力処理の終了・回収を待ち、Bot を停止して公式 switch-opencode-model でセッションを OpenCode に戻してから LLM_FALLBACK_MODELS を空にします。モデルプール対応バイナリを維持し、DB/PVC は巻き戻しません。ソース側 docs/model-pool.md に詳細があります。

## モデルプールの配布検証（2026-11-14）

CI 43548053127（2072807）の全ジョブ成功後、両 public イメージの digest を固定して反映しました。Groq Free の実 API と公式 OpenCode CLI で共有会話を検証済みです。OpenCode の11/15 09:07:05（JST）までの待機期限を保持し、受信済みのリプライを Groq で処理しました。一時的な429では待機期限を守り、11/14 11:44:46（JST）に [返信](https://misskey.y2e.org/notes/atjd9yzst4)が1回だけ投稿されました。Misskey API で返信先・投稿者・本文とログの一致、localOnly=false を確認しました。

status に provider_cooldowns を追加し、両方の待機期限を個別に確認できます。更新前の両 DB バックアップは integrity_check=ok、最終版の再起動後も共有セッションと投稿済み16件を維持しています。既存 generation_failed=1 は保持し、キュー0・不明な生成/投稿0・Pod 2/2・再起動0・readyz=200・Kustomize 差分0を確認しました。
