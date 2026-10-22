# www2.yude.jp

- コンテンツは nrt1sh1 の `/mnt/store3/html` と `/mnt/store3/teltty` からサーブされる。
- `docker/nrt1-k8s-sftp/compose.yaml` の `www2` サービスが読み取り専用 SFTP を `192.168.30.218:12223` で提供し、Caddy Pod 内の rclone FUSE が `/usr/share/caddy` にマウントする。SFTP のクライアント秘密鍵と固定ホスト鍵のピン留め値は `vault.yml` と `sealedsecret.yaml` で管理する。
- このクラスタでは `/dev/fuse` を Pod 内で開くため `privileged: true` が必要。ノードには静的ファイルをマウントしない。
