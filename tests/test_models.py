from krr_operator.models import RestartRequestSpec, TargetKind


def test_restart_spec_defaults():
    spec = RestartRequestSpec.model_validate(
        {
            "target": {
                "kind": TargetKind.DEPLOYMENT,
                "name": "demo",
                "namespace": "demo-ns",
            }
        }
    )

    assert spec.strategy.wait_for_rollout is True
    assert spec.strategy.timeout_seconds == 900
    assert spec.target.namespace == "demo-ns"


def test_blank_namespace_becomes_none():
    spec = RestartRequestSpec.model_validate(
        {
            "target": {
                "kind": TargetKind.STATEFUL_SET,
                "name": "data",
                "namespace": "",
            }
        }
    )

    assert spec.target.namespace is None
