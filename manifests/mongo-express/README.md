# Mongo Express

Credentials are encrypted in `vault.yml`. The generated `sealedsecret.yaml` is
included in `kustomization.yaml`. Do not apply a plaintext `secret.yaml`.

For a credential change, edit the Vault file, regenerate the SealedSecret with
`playbooks/seal-secret.yaml`, then apply the app manifests. Follow
[`manifests/SECRETS.md`](../SECRETS.md) for the commands. The Secret namespace
is `mongodb`.

```bash
kubectl apply -k manifests/mongo-express/
```
