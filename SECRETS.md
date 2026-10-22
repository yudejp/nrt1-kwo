# アプリの Secret の管理

各アプリの `vault.yml` は Secret の元データを Ansible Vault で暗号化したものです。
`sealedsecret.yaml` はこのクラスタの Sealed Secrets 公開証明書で封印したもので、
Kustomize から適用します。平文の `secret.yaml` は使用しません。

## 値の確認

Vault の元データを確認するには、リポジトリのルートで次を実行します。
復号された値は端末に表示されるため、画面共有や端末ログへの記録に注意してください。

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-secret-view \
ansible-vault view manifests/<app>/vault.yml --vault-password-file <password-file>
```

SealedSecret には復号用の秘密鍵を保存していません。元データを確認するときは `vault.yml` を参照します。

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
