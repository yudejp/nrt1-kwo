# Navidrome

- Tailnet 内の `https://nrt1-navidrome.tail5b1c5.ts.net/` は Tailscale Ingress ProxyGroup 経由で公開する。
- `navidrome-tun` は 192.168.30.0/24 からも到達性を確保するための専用 LoadBalancer Service で、`manifests/kube-vip-services/` が IP を ARP で広告する。
- 楽曲データは nrt1sh1 の `/mnt/store3/music` からサーブする。nrt1sh1 の `docker/nrt1-k8s-sftp/compose.yaml` で読み取り専用 SFTP を公開しており、Pod 内の rclone FUSE が `/music` にマウントする。SFTP は専用の公開鍵認証と固定ホスト鍵を使う。Navidrome 用の秘密鍵とホスト鍵のピン留め値は Ansible Vault, kubeseal を用いて保管する。
- Navidrome の `/data` は Longhorn PVC `navidrome-data` に保存する。
- 全曲同期用スマートプレイリストの原本は `all-music.nsp`。スキャン対象は `/music` に見える nrt1sh1 の `/mnt/store3/music` なので、このファイルを同ディレクトリへ配置する。Kustomize は `.nsp` をデプロイしない。音楽ディレクトリは SFTP と Pod 内 rclone FUSE の両方でキャッシュされるため、新規ファイルの反映には時間がかかる場合がある。
- `.nsp` が Pod の `/music` に見えてから `kubectl exec -n default deploy/navidrome -c navidrome -- /app/navidrome scan` で増分スキャンできる。プレイリストは既定で最初の管理者が所有し、非公開になるため、Naviamp は同じユーザーで接続する。
