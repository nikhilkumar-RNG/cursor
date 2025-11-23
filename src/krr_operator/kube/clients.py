"""Helpers for initializing Kubernetes API clients."""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache

from kubernetes import client, config
from kubernetes.config.config_exception import ConfigException


@dataclass(frozen=True)
class KubeClients:
    """Strongly typed handle to Kubernetes client instances."""

    apps: client.AppsV1Api
    core: client.CoreV1Api
    custom: client.CustomObjectsApi


def _load_config() -> None:
    """Attempt to load in-cluster configuration with a fallback to kubeconfig."""

    try:
        config.load_incluster_config()
    except ConfigException:
        config.load_kube_config()


@lru_cache(maxsize=1)
def get_kube_clients() -> KubeClients:
    """Return Kubernetes client handles, caching to avoid re-initialization."""

    _load_config()
    return KubeClients(
        apps=client.AppsV1Api(),
        core=client.CoreV1Api(),
        custom=client.CustomObjectsApi(),
    )
