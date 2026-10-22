# Service 用 kube-vip

コントロールプレーン用 kube-vip とは別の DaemonSet。`kube-vip.io/kube-vip-class` の LoadBalancer Service だけを ARP で広告する。現在の RBAC で更新できる Service は `navidrome-lan` に限定する。各ノードの `192.168.30.0/24` インターフェース名は `nodes/` のパッチで指定する。
