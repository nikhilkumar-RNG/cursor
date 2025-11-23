"""Logging helpers."""

from __future__ import annotations

import logging

from pythonjsonlogger import jsonlogger

from .config import get_config


def configure_logging() -> None:
    """Configure structured logging for the operator."""

    config = get_config()
    root = logging.getLogger()
    root.setLevel(config.log_level.upper())
    handler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter(
        "%(asctime)s %(levelname)s %(name)s %(message)s", rename_fields={"asctime": "ts"}
    )
    handler.setFormatter(formatter)
    root.handlers = [handler]
