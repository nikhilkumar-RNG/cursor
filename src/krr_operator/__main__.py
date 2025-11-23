"""Entry point for running the operator directly."""

from __future__ import annotations

import kopf

from .logging import configure_logging


def main() -> None:
    """Run Kopf with the operator modules."""

    configure_logging()
    kopf.run(standalone=True, modules=["krr_operator.handlers.restart_request"])


if __name__ == "__main__":
    main()
