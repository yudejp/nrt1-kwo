# nrt1sh1 の読み取り専用 SFTP

`compose.yaml` は nrt1sh1 の `/mnt/prod/docker/nrt1-k8s-sftp/compose.yaml` に配置する。`docker compose up -d` で起動する。音楽は `12222/tcp`、www2 の静的ファイルは `12223/tcp` で公開し、いずれも `192.168.30.218` のみにバインドする。

`authorized_keys` は Navidrome 用、`www2-authorized_keys` は www2 用の公開鍵。`host_ed25519` は SFTP サーバーの秘密ホスト鍵で、UID 65534 のみ読める権限を維持する。これらの鍵ファイルは Compose と同じディレクトリに置き、Git に追加しない。各アプリのクライアント秘密鍵はアプリの `vault.yml` と `sealedsecret.yaml` で管理する。

`/mnt/store3/music`、`/mnt/store3/html`、`/mnt/store3/teltty` の元データは移動しない。www2 では `teltty` を HTML ルート内の同名パスに重ねている。
