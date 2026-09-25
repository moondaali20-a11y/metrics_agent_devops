from fastapi.testclient import TestClient

from app.api import app

client = TestClient(app)


def test_health_endpoint():
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json() == {'status': 'ok'}


def test_metrics_latest_empty_returns_404():
    response = client.get('/metrics/latest')
    assert response.status_code == 404


def test_post_then_get_latest_metrics():
    payload = {
        'agent': 'system-metrics-agent',
        'event_type': 'system_metrics',
        'data': {
            'hostname': 'test-host',
            'timestamp': '2026-01-01T00:00:00+00:00',
            'cpu': {'percent': 10.0},
        },
    }
    post_response = client.post('/metrics', json=payload)
    assert post_response.status_code == 201

    latest_response = client.get('/metrics/latest')
    assert latest_response.status_code == 200
    latest_json = latest_response.json()
    assert latest_json['agent'] == 'system-metrics-agent'
    assert latest_json['data']['hostname'] == 'test-host'


def test_get_metrics_history():
    response = client.get('/metrics')
    assert response.status_code == 200
    res_json = response.json()
    assert 'total' in res_json
    assert isinstance(res_json['metrics'], list)
