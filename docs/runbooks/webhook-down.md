# Kyverno webhook is down

Use this when pod creation fails with a webhook timeout instead of a message that names `app/fixtures/secure/web.yaml`.

## Confirm

```bash
kubectl get pods -n kyverno
kubectl get validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg
```

`kyverno-admission-controller` should be Ready. Pod creates are decided by `kyverno-resource-validating-webhook-cfg`. If the pods are not Ready, or creates fail before a policy message is returned, the webhook is the blocker.

`kube-system` and `kyverno` are excluded from the policies, so pods in those namespaces can still be created. `paved-road` cannot.

## While it is down

Prefer bringing the admission deployment back:

```bash
kubectl rollout status -n kyverno deployment/kyverno-admission-controller --timeout=180s
```

## Break-glass

Deleting the resource webhook admits every pod, including a privileged one. Do it only to restore deploys, and put it back in the same change.

```bash
kubectl delete validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg
```

Restore it by reinstalling the chart:

```bash
make kind-up
```

## Prove the deletion did not stick

After the webhook is back, a privileged pod must be denied again:

```bash
make prove-live
```

`prove-live` applies `app/fixtures/insecure/privileged-pod.yaml` and requires the privileged-container message. If that pod is admitted, the webhook is still gone.
