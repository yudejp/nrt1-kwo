# Navidrome

- Tailnet 内の `https://nrt1-navidrome.tail5b1c5.ts.net/` は Tailscale Ingress ProxyGroup 経由で公開する。
- `navidrome-lan` は 192.168.30.0/24 からも到達性を確保するための専用 LoadBalancer Service で、`manifests/kube-vip-services/` が IP を ARP で広告する。
- 楽曲データは nrt1sh1 の `/mnt/store3/music` からサーブする。nrt1sh1 の `/mnt/prod/docker/nrt1-k8s-sftp/compose.yaml` で読み取り専用 SFTP を公開しており、Pod 内の rclone FUSE が `/music` にマウントする。SFTP は専用の公開鍵認証と固定ホスト鍵を使う。Navidrome 用の秘密鍵とホスト鍵のピン留め値は Ansible Vault, kubeseal を用いて保管する。
- Navidrome の `/data` は Longhorn PVC `navidrome-data` に保存する。
