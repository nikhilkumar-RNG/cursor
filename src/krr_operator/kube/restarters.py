"""Restart execution helpers."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from datetime import datetime, timezone

from kubernetes import client
from kubernetes.client import ApiException

from ..config import OperatorConfig
from ..exceptions import RestartError
from ..models import RestartOutcome, RestartRequestSpec, RestartStrategy, TargetKind
from .clients import KubeClients

LOG = logging.getLogger(__name__)


ANNOTATION_STRIMZI = "strimzi.io/manual-rolling-update"
ANNOTATION_CRUNCHY = "postgres-operator.crunchydata.com/restart"


@dataclass
class RestartCoordinator:
    """Dispatches restart requests to concrete implementations."""

    clients: KubeClients
    config: OperatorConfig

    def execute(self, spec: RestartRequestSpec, logger: logging.Logger) -> RestartOutcome:
        """Run the restart flow for the provided spec."""

        namespace = spec.target.namespace or self.config.default_namespace
        timestamp = datetime.now(timezone.utc).isoformat()
        logger.info(
            "Restart requested",
            extra={
                "target.kind": spec.target.kind,
                "target.name": spec.target.name,
                "namespace": namespace,
                "reason": spec.reason,
                "dry_run": spec.dry_run,
            },
        )

        if spec.dry_run:
            return RestartOutcome.now(
                target_kind=spec.target.kind,
                target_name=spec.target.name,
                namespace=namespace,
                details={"dryRun": "true", "timestamp": timestamp},
            )

        if spec.target.kind in {
            TargetKind.DEPLOYMENT,
            TargetKind.STATEFUL_SET,
            TargetKind.DAEMON_SET,
        }:
            outcome = self._restart_workload(spec, namespace, timestamp, logger)
        elif spec.target.kind is TargetKind.STRIMZI_KAFKA:
            outcome = self._restart_strimzi(spec, namespace, timestamp)
        elif spec.target.kind is TargetKind.POSTGRES_CLUSTER:
            outcome = self._restart_postgres(spec, namespace, timestamp)
        else:
            raise RestartError(f"Unsupported target kind: {spec.target.kind}")

        if spec.strategy.wait_for_rollout:
            self._wait_for_rollout(spec, namespace, logger)

        if spec.labels and spec.strategy.wait_for_rollout:
            self._wait_for_selector(namespace, spec.labels, spec.strategy, logger)

        return outcome

    def _restart_workload(
        self,
        spec: RestartRequestSpec,
        namespace: str,
        timestamp: str,
        logger: logging.Logger,
    ) -> RestartOutcome:
        patch_body = {
            "metadata": {
                "annotations": {
                    self.config.restart_annotation_key: timestamp,
                }
            },
            "spec": {
                "template": {
                    "metadata": {
                        "annotations": {
                            self.config.restart_annotation_key: timestamp,
                        }
                    }
                }
            },
        }

        patch = client.V1Patch(patch_body)

        try:
            if spec.target.kind is TargetKind.DEPLOYMENT:
                self.clients.apps.patch_namespaced_deployment(
                    name=spec.target.name, namespace=namespace, body=patch
                )
            elif spec.target.kind is TargetKind.STATEFUL_SET:
                self.clients.apps.patch_namespaced_stateful_set(
                    name=spec.target.name, namespace=namespace, body=patch
                )
            elif spec.target.kind is TargetKind.DAEMON_SET:
                self.clients.apps.patch_namespaced_daemon_set(
                    name=spec.target.name, namespace=namespace, body=patch
                )
        except ApiException as exc:
            raise RestartError(f"Failed to patch workload {spec.target.kind}: {exc}") from exc

        logger.info(
            "Workload template annotation patched",
            extra={
                "target.kind": spec.target.kind,
                "target.name": spec.target.name,
                "namespace": namespace,
            },
        )

        return RestartOutcome.now(
            target_kind=spec.target.kind,
            target_name=spec.target.name,
            namespace=namespace,
            details={"annotation": self.config.restart_annotation_key, "value": timestamp},
        )

    def _restart_strimzi(
        self, spec: RestartRequestSpec, namespace: str, timestamp: str
    ) -> RestartOutcome:
        patch = {"metadata": {"annotations": {ANNOTATION_STRIMZI: timestamp}}}

        try:
            self.clients.custom.patch_namespaced_custom_object(
                group=self.config.strimzi_group,
                version=self.config.strimzi_version,
                namespace=namespace,
                plural=spec.target.plural or "kafkas",
                name=spec.target.name,
                body=patch,
            )
        except ApiException as exc:
            raise RestartError(f"Failed to patch Strimzi Kafka resource: {exc}") from exc

        return RestartOutcome.now(
            target_kind=spec.target.kind,
            target_name=spec.target.name,
            namespace=namespace,
            details={"annotation": ANNOTATION_STRIMZI, "value": timestamp},
        )

    def _restart_postgres(
        self, spec: RestartRequestSpec, namespace: str, timestamp: str
    ) -> RestartOutcome:
        patch = {"metadata": {"annotations": {ANNOTATION_CRUNCHY: timestamp}}}

        plural = spec.target.plural or "postgresclusters"

        try:
            self.clients.custom.patch_namespaced_custom_object(
                group=self.config.postgres_group,
                version=self.config.postgres_version,
                namespace=namespace,
                plural=plural,
                name=spec.target.name,
                body=patch,
            )
        except ApiException as exc:
            raise RestartError(f"Failed to patch Postgres cluster: {exc}") from exc

        return RestartOutcome.now(
            target_kind=spec.target.kind,
            target_name=spec.target.name,
            namespace=namespace,
            details={"annotation": ANNOTATION_CRUNCHY, "value": timestamp},
        )

    def _wait_for_rollout(
        self, spec: RestartRequestSpec, namespace: str, logger: logging.Logger
    ) -> None:
        """Wait for Kubernetes workload rollouts."""

        deadline = time.time() + spec.strategy.timeout_seconds

        while time.time() < deadline:
            if spec.target.kind is TargetKind.DEPLOYMENT:
                if self._deployment_ready(spec.target.name, namespace):
                    logger.info("Deployment rollout completed", extra={"target": spec.target.name})
                    return
            elif spec.target.kind is TargetKind.STATEFUL_SET:
                if self._stateful_set_ready(spec.target.name, namespace):
                    logger.info("StatefulSet rollout completed", extra={"target": spec.target.name})
                    return
            elif spec.target.kind is TargetKind.DAEMON_SET:
                if self._daemon_set_ready(spec.target.name, namespace):
                    logger.info("DaemonSet rollout completed", extra={"target": spec.target.name})
                    return
            else:
                # For CRDs we rely on label selectors instead.
                return

            time.sleep(spec.strategy.poll_interval_seconds)

        raise RestartError(
            f"Timeout waiting for {spec.target.kind} {spec.target.name} rollout completion"
        )

    def _deployment_ready(self, name: str, namespace: str) -> bool:
        dep = self.clients.apps.read_namespaced_deployment_status(name=name, namespace=namespace)
        spec_replicas = dep.spec.replicas or 0
        status = dep.status
        return (
            status.updated_replicas == spec_replicas
            and status.available_replicas == spec_replicas
            and status.observed_generation is not None
            and dep.metadata.generation is not None
            and status.observed_generation >= dep.metadata.generation
        )

    def _stateful_set_ready(self, name: str, namespace: str) -> bool:
        sts = self.clients.apps.read_namespaced_stateful_set_status(name=name, namespace=namespace)
        spec_replicas = sts.spec.replicas or 0
        status = sts.status
        return (
            status.ready_replicas == spec_replicas
            and status.current_replicas == spec_replicas
            and status.update_revision == status.current_revision
        )

    def _daemon_set_ready(self, name: str, namespace: str) -> bool:
        ds = self.clients.apps.read_namespaced_daemon_set_status(name=name, namespace=namespace)
        status = ds.status
        return status.desired_number_scheduled == status.number_available

    def _wait_for_selector(
        self,
        namespace: str,
        labels: dict[str, str],
        strategy: RestartStrategy,
        logger: logging.Logger,
    ) -> None:
        """Wait for pods matching the selector to become ready."""

        selector = ",".join(f"{key}={value}" for key, value in labels.items())
        deadline = time.time() + strategy.timeout_seconds

        while time.time() < deadline:
            pods = self.clients.core.list_namespaced_pod(
                namespace=namespace, label_selector=selector
            ).items
            if pods and all(_pod_ready(pod) for pod in pods):
                logger.info(
                    "All pods for selector became ready",
                    extra={"namespace": namespace, "selector": selector},
                )
                return
            time.sleep(strategy.poll_interval_seconds)

        raise RestartError(f"Timeout waiting for pods with selector {selector} to become ready")


def _pod_ready(pod: client.V1Pod) -> bool:
    if pod.status is None or pod.status.conditions is None:
        return False
    for condition in pod.status.conditions:
        if condition.type == "Ready":
            return condition.status == "True"
    return False
