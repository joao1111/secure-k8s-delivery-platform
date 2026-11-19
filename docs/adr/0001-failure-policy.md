# Failure policy

## Decision

Admission policies set `spec.failurePolicy: Fail` and `spec.validationActions: [Deny]`. If Kyverno cannot evaluate a policy, the API server rejects the pod. The alternative, `Ignore`, would admit the pod when the webhook times out or the policy errors.

## What is excluded

`kube-system` and `kyverno` are outside the match conditions. Calico and the admission controller live there. A webhook outage must not freeze those namespaces. Every other namespace, including `paved-road`, fails closed.

Background scanning is off. The control that matters here is admission. A pod that is already running is not retroactively stopped by these policies.

## What a timeout does

The webhook has a short timeout. When it is exceeded, `failurePolicy: Fail` turns the timeout into a denied create. The error text is a webhook timeout, not the policy message that tells the developer what to change. That difference is how you tell an outage from a real policy denial. See [the webhook runbook](../runbooks/webhook-down.md).

## Installing the same choice

`make kind-up` installs Kyverno 1.20.0 with Helm chart 3.10.0 and one replica of each controller. Policy exceptions are off in that chart until `features.policyExceptions.enabled` is true, and the namespace is `*` so a reviewed exception can live next to the workload. `features.forceFailurePolicyIgnore` stays at its default, `false`, so a webhook timeout is not turned into an allow. The chart also excludes `kube-system` and the Kyverno namespace from the webhook itself. The policy objects carry `failurePolicy: Fail` on top of that. Kyverno 1.20 does not execute the older `ClusterPolicy` type, so these controls are `ValidatingPolicy` and `ImageValidatingPolicy`.
