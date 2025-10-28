# Operating Percona PostgreSQL Cluster

This guide covers routine operations for Percona Operator for PostgreSQL 2.x clusters: backup, PITR, recovery, upgrade, monitoring, and troubleshooting.

## Topology
- Operator namespace: `percona-pg-operator`
- Cluster namespace(s): e.g., `postgres-dev`
- Cluster CR: `PerconaPGCluster` named `dev-pg`
- PgBouncer service: `dev-pg-pgbouncer`

## Access
- Port-forward PgBouncer: `kubectl -n postgres-dev port-forward svc/dev-pg-pgbouncer 5432`
- Credentials: check `dev-pg-users` secret for generated users.

## Backup (pgBackRest)
- Trigger full backup:
  ```bash
  kubectl -n postgres-dev exec -it sts/dev-pg-primary-0 -- pgbackrest backup --type=full --stanza=db
  ```
- Check backups:
  ```bash
  kubectl -n postgres-dev exec -it sts/dev-pg-primary-0 -- pgbackrest info
  ```

## PITR
- Create a `PerconaPGRestore` CR (example in `infra/postgresql/clusters/dev/restore-example.yaml`) and set target timestamp.
- Monitor restore progress via `kubectl -n postgres-dev get perconapgrestore -w` and pod logs.

## Monitoring
- PrometheusRule and Grafana dashboards are applied via GitOps under `infra/postgresql/monitoring/`.
- Ensure ServiceMonitor/PodMonitor from operator are discovered by your Prometheus.

## Upgrades
- Bump `HelmRelease` chart `version` for operator.
- For PostgreSQL minor upgrades, roll through cluster by updating CR as per Percona docs.

## Recovery
- For full restore, create a new cluster from S3 by setting `init` and pointing to repo in the cluster CR as per docs.

## Notes
- IRSA provides S3 access. Ensure IAM role trust policy allows the cluster service account.
- TLS is handled via cert-manager if enabled in values; verify secrets and SANs.
