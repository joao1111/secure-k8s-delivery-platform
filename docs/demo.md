# Command walkthrough

No recording. Run these from a checkout and compare the output.

Offline, with no cluster:

```bash
make prove
```

Expected: Kyverno reports the privileged, root, and host fixtures failing and `app/fixtures/secure/web.yaml` passing. The expired exception and the expired suppression are rejected. Gitleaks, Semgrep, Checkov, and Trivy each fail their bad fixture and pass the paved road. The last line of the catalog check is `ok 11 catalog rows`.

Cluster:

```bash
make kind-up
make prove-live
```

Expected, in order:

1. `golden pod Ready` after `pod/web` becomes Ready.
2. `denied privileged-pod.yaml` and the message `Privileged containers are denied`.
3. `denied root-pod.yaml` and the message `Containers must run as non-root`.
4. `denied hostpath-pod.yaml`, `host-network-pod.yaml`, `host-pid-pod.yaml`, and `host-ipc-pod.yaml`.
5. `labeled root pod admitted by exception`, then `denied root-pod.yaml` again for the pod without the label.
6. `labeled client reached web`.
7. `unlabeled client blocked`.
8. `prove-live ok`.

The image signature check runs in `.github/workflows/release.yml` after a push to `main`. The unsigned pod is `app/fixtures/insecure/unsigned-server.yaml`. The workflow must print `unsigned image denied` and `signed digest admitted`.

```bash
make kind-down
```
