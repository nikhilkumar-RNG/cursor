"""Runtime configuration for the Kubernetes Restart Operator."""

from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache


@dataclass(frozen=True)
class OperatorConfig:
    """Holds configurable runtime knobs sourced from the environment."""

    log_level: str = "INFO"
    default_namespace: str = "default"
    restart_annotation_key: str = "krr.sh/restartedAt"
    readiness_timeout_seconds: int = 900
    readiness_poll_interval_seconds: int = 5
    strimzi_group: str = "kafka.strimzi.io"
    strimzi_version: str = "v1beta2"
    postgres_group: str = "postgres-operator.crunchydata.com"
    postgres_version: str = "v1beta1"

    @classmethod
    def from_env(cls) -> OperatorConfig:
        """Create configuration loading overrides from environment variables."""

        def _int(name: str, default: int) -> int:
            value = os.getenv(name)
            return int(value) if value else default

        return cls(
            log_level=os.getenv("KRR_LOG_LEVEL", cls.log_level),
            default_namespace=os.getenv("KRR_DEFAULT_NAMESPACE", cls.default_namespace),
            restart_annotation_key=os.getenv(
                "KRR_RESTART_ANNOTATION", cls.restart_annotation_key
            ),
            readiness_timeout_seconds=_int(
                "KRR_READINESS_TIMEOUT_SECONDS", cls.readiness_timeout_seconds
            ),
            readiness_poll_interval_seconds=_int(
                "KRR_READINESS_POLL_SECONDS", cls.readiness_poll_interval_seconds
            ),
            strimzi_group=os.getenv("KRR_STRIMZI_GROUP", cls.strimzi_group),
            strimzi_version=os.getenv("KRR_STRIMZI_VERSION", cls.strimzi_version),
            postgres_group=os.getenv("KRR_POSTGRES_GROUP", cls.postgres_group),
            postgres_version=os.getenv("KRR_POSTGRES_VERSION", cls.postgres_version),
        )


@lru_cache(maxsize=1)
def get_config() -> OperatorConfig:
    """Return a cached configuration instance."""

    return OperatorConfig.from_env()
