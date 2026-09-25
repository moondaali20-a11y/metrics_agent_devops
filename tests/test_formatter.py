import pytest
from app.formatter import format_metrics


def test_format_metrics_structure():
    raw_metrics = {
        'timestamp': '2026-09-25T12:00:00Z',
        'hostname': 'test-host',
        'cpu': {'percent': 10.0, 'logical_cores': 4},
        'memory': {
            'total_bytes': 1000,
            'available_bytes': 500,
            'used_bytes': 500,
            'percent': 50.0,
        },
        'system': {'load_1m': 0.1, 'load_5m': 0.1, 'load_15m': 0.1},
    }
    payload = format_metrics(raw_metrics)
    assert payload['agent'] == 'system-metrics-agent'
    assert payload['event_type'] == 'system_metrics'
    assert payload['data'] == raw_metrics


def test_format_metrics_missing_keys():
    incomplete_metrics = {'timestamp': '2026-09-25T12:00:00Z'}
    with pytest.raises(ValueError):
        format_metrics(incomplete_metrics)
