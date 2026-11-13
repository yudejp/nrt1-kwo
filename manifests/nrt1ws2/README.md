# nrt1ws2

## 適用・確認

```sh
kubectl kustomize manifests/nrt1ws2/ > /dev/null
kubectl apply --dry-run=server -k manifests/nrt1ws2/
kubectl apply -k manifests/nrt1ws2/
kubectl rollout status deployment/rdp-web -n default
kubectl get -k manifests/nrt1ws2/
```

## Windows 7 の描画互換設定

`RDP_LEGACY_GRAPHICS=true` を設定しています。GFX・ビットマップキャッシュ・画面外キャッシュを無効にし、
32 bit 色と固定解像度で接続します。壁紙・テーマ・フォント平滑化は有効です。
ブラウザのリサイズ時は縮小表示し、Windows 側の解像度変更には再接続が必要です。

初期版で認証とデスクトップの一部表示は成功しましたが、アイコンが途中で切れ、タスクバーが表示されない症状が報告されました。
同じ JavaScript/CSS/CSP で 1920×1080 の右下まで描画できることは headless Chromium で確認しました。
修正版の適用後、ユーザー側で再接続し、デスクトップとスタートメニューの表示が正常になったことを確認しました。
GFX・各キャッシュのどの機能が単独の原因かは未特定です。

## 再生音声

Windows の再生音声をブラウザへ転送します。PCM 44.1 kHz / 16 bit / stereo を交渉し、
接続ボタンの操作時に Web Audio の再生を開始します。上部の音声ボタンでオン・オフを切り替えられます。
マイク入力は無効です。

Go の race test / vet、音声形式と有効化パラメーターのハンドシェイクを検証しました。
headless Chromium では、Guacamole の音声ストリームから非ゼロの stereo 音声バッファの再生、ACK、
音声のオン・オフ切り替え、JavaScript エラーなしを確認しました。
guacd への音声形式の通知を `audio/L16` に修正し、Windows のテスト音から実際の PCM データが guacd を通って届くことを確認しました。

## Windows 側の TLS 診断・変更（2026-11-04）

VM は `nrt1pve1.tail5b1c5.ts.net` の VM 105 です。
Schannel のイベント 36874/36888 と認証前の TLS 接続試験で、
旧 SHA-1 証明書使用時のハンドシェイク失敗を確認しました。
RSA/SHA-256 証明書では標準 TLS 接続は成功しましたが、ブラウザでは
WSA 10054 が継続したため、ECDSA P-256/SHA-256 証明書に切り替えました。

- 現在の RDP-Tcp 証明書: `DB62B3616E53CC0A7408437EE47A19B3F3A5726F`
- 接続試験で成功した暗号: `ECDHE-ECDSA-AES128-GCM-SHA256`（TLS 1.2）
- 保持した RSA/SHA-256 証明書: `EA1671D353A1C7212702D5C53F9FB1A6D398BF9E`
- 保持した元の自動証明書: `BD20238804F95EB8D8B60D66B73B9BA2080B320C`
- ゲスト内バックアップ・復旧スクリプト: `C:\ProgramData\rdp105-tls-20261104\`

証明書の切り替えに VM・RDP サービスの再起動は行っていません。
認証方式・SecurityLayer は変更していません。
元の設定へ戻す場合は、同ディレクトリの `rollback.ps1` を管理者で実行します。
復旧スクリプトは RDP サービスを再起動するため、接続中のセッションは切断されます。

ECDSA 切り替え後、一度 WSA 10013 が報告されましたが、提供された
Gateway Network ログ（2026-11-04 08:09:45 JST）は `clientless_rdp` /
`allow` / `cloudflare_tunnel` を示していました。
経路・URL の VNET/IP/ポートの一致と `warp-routing.enabled: true` は確認済みです。

08:18 JST のブラウザ再試行を Proxmox ホスト上で記録すると、実際の
Tunnel ノード `nrt1kwo3`（`192.168.30.225`）から対象への接続があり、
ClientHello の暗号候補は `1302,1301,c02c,c02b,c030,c02f,00ff`、
ServerHello は TLS 1.2 / `c02b`（ECDHE-ECDSA-AES128-GCM-SHA256）でした。
ハンドシェイク後も暗号化データが双方向に流れ、この新規接続のリセットは
記録されませんでした。ただし暗号化されたデータの内容は未確認です。

ユーザー側では青い画面のまま停止したと報告されています。
VM コンソールは正常な Windows ロック画面でした。
ブラウザでのデスクトップ表示成功は未確認で、表示中の画面と
描画・セッション初期化の切り分けが残っています。
Gateway ポリシーの Block が原因だとは確定していません。

08:25-08:26 JST に、コンソールとブラウザ版 RDP の同一ユーザーセッション内で
Explorer/DWM の応答・イベント・画面画像を比較しました。
ブラウザが青い画面の間も、ゲスト内の画面取得では通常のデスクトップが描画され、
セッション再接続成功イベントが記録されました。全面再描画の要求は成功しましたが、
ユーザー側の表示は改善しませんでした。別ブラウザでも同じ症状が報告されました。
描画方式の互換性が有力ですが、具体的なコーデックや不具合箇所は未特定です。
表示関連のレジストリ・RemoteFX/RDP 8 ポリシーは変更していません。

- [ブラウザ版 RDP の構成と対応 OS](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/rdp/rdp-browser/)
- [warp-routing 設定の廃止](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/)
