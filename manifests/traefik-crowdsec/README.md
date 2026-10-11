# Traefik と CrowdSec

Cloudflare Tunnel Controller 用 Ingress は `kube-system/traefik` Service に渡します。
アプリ側には同じホストの `traefik` Ingress を置き、転送先 Service を指定します。
公開設定は各アプリの `cloudflare-ingress.yaml` で編集できます。

この HelmChartConfig は既存 k3s Traefik のアクセスログを JSON で stdout に出し、
Pod CIDR `10.42.0.0/16` から来た `X-Forwarded-For` を信頼します。
Pod CIDR が変わる場合は更新してください。CrowdSec は
`manifests/crowdsec/helmchart.yaml` の Agent が Traefik の CRI ログを読み、
`crowdsecurity/traefik` コレクションで解析します。現構成は検出のみで、
遮断は設定していません。

確認例:

```sh
kubectl -n kube-system rollout status deployment/traefik
kubectl -n crowdsec rollout status daemonset/crowdsec-agent
kubectl -n crowdsec exec daemonset/crowdsec-agent -- cscli metrics show acquisition parsers
```
