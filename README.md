# Kubernetes Restart Operator (KRR)

KRR is a Python-based Kubernetes operator that brings structure, auditability, and safety to
restarting common platform resources such as Deployments, StatefulSets, Strimzi Kafka clusters, and
Crunchy Postgres clusters. It ships with a single Custom Resource Definition (CRD), **RestartRequest**,
which captures the intent, strategy, and rollout expectations for each restart.

## Why build KRR?

- **Consistent workflows** – replace ad-hoc `kubectl rollout restart` commands with GitOps-friendly
  manifests.
- **First-class support for popular CRDs** – Strimzi and Crunchy Postgres restart workflows follow
  vendor recommendations out of the box.
- **Observability ready** – structured JSON logs, explicit status phases, and idempotent spec hashes
  make it easy to integrate with alerting or incident tooling.
- **Extensible** – add new target kinds by dropping in additional restarters without changing the CRD.

## Features

- Restart Deployments, StatefulSets, and DaemonSets via deterministic template annotations.
- Trigger Strimzi rolling updates by annotating Kafka CRs.
- Request Crunchy Postgres restarts using the official restart annotation.
- Optional dry-run mode to preview actions.
- Built-in rollout waiting, readiness polling, and pod selector checks.
- Kopf-powered reconciliation with retry backoff and status management.

## Repository layout

```
src/krr_operator/        # Operator source (handlers, restarters, config)
deploy/crds/             # RestartRequest CRD
deploy/operator/         # Namespace, RBAC, Deployment manifests
manifests/examples/      # Sample RestartRequest definitions
tests/                   # Unit tests for spec validation
```

## Getting started locally

1. **Install dependencies**

   ```bash
   pip install -e .[dev]
   ```

2. **Run tests and linters**

   ```bash
   make lint test
   ```

3. **Start the operator against your current kubeconfig**

   ```bash
   make run
   ```

   Kopf will connect to whichever cluster is configured in your `KUBECONFIG`. Use `kind`,
   `minikube`, or an actual cluster.

## Deploying to a cluster

1. Apply the CRD and RBAC/operator manifests (edit the image reference first):

   ```bash
   kubectl apply -f deploy/crds/restartrequests.restart.krr.sh.yaml
   kubectl apply -f deploy/operator/krr-operator.yaml
   ```

2. Build and push an image:

   ```bash
   docker build -t ghcr.io/<org>/krr-operator:latest .
   docker push ghcr.io/<org>/krr-operator:latest
   ```

3. Update `deploy/operator/krr-operator.yaml` with your image reference and re-apply.

The operator creates one Deployment in the `krr-system` namespace and watches all
`RestartRequest` CRs cluster-wide.

## Creating a restart request

Example manifest for a Deployment restart:

```yaml
apiVersion: restart.krr.sh/v1alpha1
kind: RestartRequest
metadata:
  name: refresh-web
spec:
  target:
    kind: Deployment
    name: web
    namespace: default
  reason: "Pick up new ConfigMap data"
  strategy:
    waitForRollout: true
    timeoutSeconds: 1200
```

More examples, including Strimzi Kafka and Postgres clusters, live under
`manifests/examples/restart-examples.yaml`.

## Supported targets

| Kind             | Action performed                                                                    |
| ---------------- | ------------------------------------------------------------------------------------ |
| Deployment       | Patches `spec.template.metadata.annotations` with `krr.sh/restartedAt` timestamp     |
| StatefulSet      | Same as Deployment                                                                   |
| DaemonSet        | Same as Deployment                                                                   |
| StrimziKafka     | Applies the `strimzi.io/manual-rolling-update` annotation to the Kafka CR            |
| PostgresCluster  | Applies the `postgres-operator.crunchydata.com/restart` annotation to the CR         |

If `spec.labels` are provided, KRR also polls pods matching the selector to ensure readiness.

## Extending the operator

1. Add a new `TargetKind` enum entry inside `src/krr_operator/models.py`.
2. Teach `RestartCoordinator` how to handle that kind.
3. Update the CRD schema and documentation.
4. Contribute tests that exercise the new behavior (mocking Kubernetes clients).

## Contributing

Contributions are welcome! Please open an issue or discussion for substantial feature work. For pull
requests:

- Keep code formatted with `ruff`.
- Add or update tests for behavioral changes.
- Update documentation when adding new capabilities.

## License

MIT – see `LICENSE` for details.
