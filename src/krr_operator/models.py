"""Data models shared by controllers."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class TargetKind(str, Enum):
    DEPLOYMENT = "Deployment"
    STATEFUL_SET = "StatefulSet"
    DAEMON_SET = "DaemonSet"
    STRIMZI_KAFKA = "StrimziKafka"
    POSTGRES_CLUSTER = "PostgresCluster"


class StrategyType(str, Enum):
    ROLLING = "rolling"
    FULL = "full"


class RestartStrategy(BaseModel):
    """Fine grained controls for restart execution."""

    type: StrategyType = StrategyType.ROLLING
    wait_for_rollout: bool = True
    timeout_seconds: int = Field(900, ge=30, le=7200)
    poll_interval_seconds: int = Field(5, ge=1, le=60)


class RestartTarget(BaseModel):
    """Target object that should be restarted."""

    kind: TargetKind
    name: str
    namespace: str | None = None
    api_version: str | None = None
    plural: str | None = None

    @field_validator("namespace", mode="before")
    @classmethod
    def default_namespace(cls, namespace: str | None) -> str | None:
        """Normalize empty strings to None."""

        if namespace == "":
            return None
        return namespace


class RestartRequestSpec(BaseModel):
    """Schema for the RestartRequest custom resource spec."""

    target: RestartTarget
    reason: str | None = None
    strategy: RestartStrategy = RestartStrategy()
    dry_run: bool = False
    labels: dict[str, str] | None = None


class RestartPhase(str, Enum):
    PENDING = "Pending"
    IN_PROGRESS = "InProgress"
    SUCCEEDED = "Succeeded"
    FAILED = "Failed"
    SKIPPED = "Skipped"


@dataclass
class RestartOutcome:
    """Runtime result describing the restart event."""

    target_kind: TargetKind
    target_name: str
    namespace: str
    restarted_at: datetime
    details: dict[str, str] | None = None

    @classmethod
    def now(
        cls,
        *,
        target_kind: TargetKind,
        target_name: str,
        namespace: str,
        details: dict[str, str] | None = None,
    ) -> RestartOutcome:
        return cls(
            target_kind=target_kind,
            target_name=target_name,
            namespace=namespace,
            restarted_at=datetime.now(timezone.utc),
            details=details,
        )
