# Decommissioning Zalando PostgreSQL Operator

## Pre-checks
- Applications fully switched to Percona cluster
- All required backups verified in S3 (Percona)
- Retention window for old cluster elapsed (per policy)

## Steps
1. Scale Zalando clusters to zero replicas
2. Remove scheduled backups and monitoring for Zalando
3. Delete Zalando `postgresql` CRs
4. Remove Zalando Operator HelmRelease and CRDs
5. Clean up secrets, configmaps, and PVCs (after final confirmation)

## Rollback
- If issues arise post-decommission, restore from Percona backups or re-enable the old Zalando cluster if still retained
