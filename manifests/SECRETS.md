# アプリの Secret の管理

各アプリの `vault.yml` は Secret の元データを Ansible Vault で暗号化したものです。
`sealedsecret.yaml` はこのクラスタの Sealed Secrets 公開証明書で封印したもので、
Kustomize から適用します。平文の `secret.yaml` は使用しません。

対象は `es-meili-growi-bridge`、`growi`、`meilisearch`、`mongo-express`、
`swarm-checkin`、`swarm-keikenchi`、`tapo-power-grafana`、`ticket`、
`vaultwarden` です。`swarm-checkin` は専用の
`swarm-checkin-foursquare-credentials` を使い、`swarm-keikenchi` は
`foursquare-credentials` を使います。

## 値の更新

以下の `<app>` と `<password-file>` を置き換えます。Vault パスワードファイルは
リポジトリ外に置き、所有者のみ読める権限にしてください。

```bash
ansible-vault edit manifests/<app>/vault.yml --vault-password-file <password-file>
ANSIBLE_BECOME_ASK_PASS=false \
ANSIBLE_LOCAL_TEMP=/tmp/ansible-secret-seal \
ANSIBLE_REMOTE_TEMP=/tmp/ansible-secret-seal-remote \
ansible-playbook -i localhost, -c local playbooks/seal-secret.yaml \
  -e secret_dir=manifests/<app> --vault-password-file <password-file>
kubeseal --validate < manifests/<app>/sealedsecret.yaml
kubectl apply -f manifests/<app>/sealedsecret.yaml
kubectl get sealedsecret -n <namespace> <secret-name>
```

`sealedsecret.yaml` の `status.conditions` に `Synced: True` が出るまで確認します。
値を変更した際は、その値を使う Pod の再起動が必要かも確認してください。
`pub-cert.pem` はクラスタの公開証明書です。クラスタを再構築した場合は、
新しい証明書を取得してから再封印します。Vault パスワードは Git に保存しません。

既存の平文 Secret を SealedSecret 管理に移すときは、Secret に
`sealedsecrets.bitnami.com/managed=true` と
`sealedsecrets.bitnami.com/patch=true` を付けてから Controller を再起動します。
この移行は 2026-10-12 に対象 8 件へ実施済みです。`swarm-checkin` の専用 Secret は
SealedSecret から新規作成しました。
