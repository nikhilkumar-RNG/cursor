"""Kopf handlers for RestartRequest custom resources."""

from __future__ import annotations

import hashlib
import json
import logging
from functools import lru_cache

import kopf

from ..config import get_config
from ..exceptions import RestartError
from ..kube.clients import get_kube_clients
from ..kube.restarters import RestartCoordinator
from ..logging import configure_logging
from ..models import RestartPhase, RestartRequestSpec

LOGGER = logging.getLogger(__name__)


def _hash_spec(spec: dict) -> str:
    return hashlib.sha256(json.dumps(spec, sort_keys=True).encode("utf-8")).hexdigest()


@lru_cache(maxsize=1)
def _get_coordinator() -> RestartCoordinator:
    return RestartCoordinator(clients=get_kube_clients(), config=get_config())


@kopf.on.startup()
def configure(settings: kopf.OperatorSettings, **_: object) -> None:
    """Set Kopf defaults once at startup."""

    configure_logging()
    cfg = get_config()
    settings.posting.level = cfg.log_level.upper()
    settings.watching.server_timeout = 60
    settings.watching.client_timeout = 70
    LOGGER.info("KRR operator starting", extra={"log_level": cfg.log_level})


@kopf.on.create("restart.krr.sh", "v1alpha1", "restartrequests")
@kopf.on.update("restart.krr.sh", "v1alpha1", "restartrequests")
@kopf.on.resume("restart.krr.sh", "v1alpha1", "restartrequests")
def on_restart_request(spec, status, patch, logger, **_: object):
    """Main reconciliation loop."""

    cfg = get_config()
    request = RestartRequestSpec.model_validate(spec)
    namespace = request.target.namespace or cfg.default_namespace
    spec_hash = _hash_spec(spec)

    if status:
        last_hash = status.get("specHash")
        phase = status.get("phase")
        if last_hash == spec_hash and phase == RestartPhase.SUCCEEDED.value:
            logger.info(
                "Spec already reconciled, skipping",
                extra={"target": request.target.name, "namespace": namespace},
            )
            patch.status["phase"] = RestartPhase.SKIPPED.value
            return

    patch.status["phase"] = RestartPhase.IN_PROGRESS.value
    patch.status["namespace"] = namespace
    patch.status["specHash"] = spec_hash

    coordinator = _get_coordinator()

    try:
        outcome = coordinator.execute(request, logger=logger)
        patch.status.update(
            {
                "phase": RestartPhase.SUCCEEDED.value,
                "lastRestartAt": outcome.restarted_at.isoformat(),
                "details": outcome.details,
            }
        )
        logger.info(
            "Restart completed",
            extra={
                "target.kind": request.target.kind,
                "target.name": request.target.name,
                "namespace": namespace,
            },
        )
    except RestartError as exc:
        patch.status.update({"phase": RestartPhase.FAILED.value, "message": str(exc)})
        raise kopf.TemporaryError(str(exc), delay=30) from exc


@kopf.on.delete("restart.krr.sh", "v1alpha1", "restartrequests")
def on_delete(body, logger, **_: object):
    """Log deletes to keep an audit trail."""

    metadata = body.get("metadata", {})
    logger.info(
        "RestartRequest deleted",
        extra={"name": metadata.get("name"), "namespace": metadata.get("namespace")},
    )
