"""Operator specific exceptions."""


class RestartError(RuntimeError):
    """Raised when a restart operation fails."""


class DryRunNotice(RuntimeError):
    """Raised to short-circuit execution when running in dry-run mode."""
