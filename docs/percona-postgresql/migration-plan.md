# Migration Plan: Zalando Operator -> Percona Operator for PostgreSQL 2.x

## Scope
Migrate existing PostgreSQL clusters managed by Zalando Operator to Percona Operator, enabling S3 WAL backups (pgBackRest), integrated monitoring, and predictable recovery.

## Prereqs
- IAM role for IRSA with S3 access (list/get/put/delete on backup bucket)
- S3 bucket created (versioning recommended)
- Flux installed and managing `infra/postgresql/`
- StorageClass validated (e.g., `gp3` + EBS CSI snapclass)

## Steps
1. Deploy operator
   - Apply `infra/postgresql/operator` via Flux/PR
   - Verify operator pods ready
2. Create dev cluster
   - Apply `infra/postgresql/clusters/dev`
   - Wait for primary + replicas ready
3. Configure backup
   - Verify pgBackRest repo in S3, run initial full backup
4. Import data
   - Logical: `pg_dump` from Zalando -> `psql` to Percona
   - Or PITR: upload base backup to S3 and set restore init on new cluster
5. Validate
   - Run smoke queries; check replication, backups, WAL archiving
6. Traffic switch
   - Point applications to PgBouncer service `dev-pg-pgbouncer`
   - Monitor latency/errors; keep old cluster read-only for a window
7. Post-switch
   - Enable scheduled backups; confirm alerts and dashboards
8. Decommission Zalando
   - Scale to zero; delete CRDs after data retention window

## Verification
- PITR to timestamp T works on new test cluster
- Prometheus shows metrics; Grafana dashboards populated
- Alerts firing for synthetic failures
