from app.collector import collect_system_metrics, get_load_average


def test_get_load_average_keys():
    load = get_load_average()
    assert set(load.keys()) == {'load_1m', 'load_5m', 'load_15m'}


def test_collect_system_metrics_structure():
    data = collect_system_metrics()
    assert 'timestamp' in data
    assert 'hostname' in data
    assert 'cpu' in data
    assert 'memory' in data
    assert 'system' in data
    assert 'percent' in data['cpu']
    assert 'total_bytes' in data['memory']
