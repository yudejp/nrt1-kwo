# Cloudflare Tunnel Controller の認証情報

公開経路は各アプリの `cloudflare-ingress.yaml` に置きます。各ファイルは
Cloudflare Tunnel から Traefik に渡す Ingress と、Traefik からアプリに渡す Ingress
の 2 件を定義します。旧 cloudflared と
新コントローラーで同じ DNS 名を同時に管理しないでください。

1. Sealed Secrets Controller は `manifests/sealed-secrets/` で管理します。
   このクラスタから取得した公開証明書が `pub-cert.pem` です。
   復旧時には Controller の秘密鍵の別途バックアップも必要です。
2. このディレクトリで `export ANSIBLE_LOCAL_TEMP=/tmp/ansible-cloudflare` を実行します。
   `cp vault.yml.example vault.yml` の後、値を記入する前に
   `ansible-vault encrypt vault.yml --ask-vault-pass` で暗号化します。
   `ansible-vault edit vault.yml --ask-vault-pass` でアカウント ID、トンネル名、
   API トークンを記入します。トークンには Zone:Read、DNS:Edit、
   Account:Cloudflare Tunnel:Edit を付けます。
3. `ansible-playbook seal.yaml --ask-vault-pass` を実行します。最初に API トークンから
   `yude.jp.eu.org` と `y2e.org` の両 Zone が見えることを検証し、成功した場合だけ `sealedsecret.yaml` を作成して
   `kustomization.yaml` の resources に追加されます。
4. `vault.yml` が `$ANSIBLE_VAULT;` で始まること、`sealedsecret.yaml` に
   `kind: SealedSecret` と `name: cloudflare-api` があることを確認してから Git に保存します。
   平文の Secret と Vault パスワードは Git に保存しません。
5. `kubectl apply -k manifests/cloudflare-tunnel-controller/` で反映します。
   トークンを更新した場合は Controller が起動時に読み込んだ値を使い続けるため、
   `kubectl -n cloudflare-tunnel-system rollout restart deployment/cloudflare-tunnel-ingress-controller`
   の後に rollout と DNS 更新結果を確認します。

トンネル名は新しい専用名を推奨します。DNS 切り替え前に新旧トンネルの競合を避けます。
旧 cloudflared は、今回移行しない Misskey やマニフェストのないアプリも公開しているため、
それらの移行または公開終了が済むまで稼働を続けます。
