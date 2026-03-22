"""冒烟测试：不依赖旧 client 路径；main_v2 未启动时自动 skip。"""

from __future__ import annotations

import json
import urllib.error
import urllib.request

import pytest

BASE = "http://127.0.0.1:8080"
TOKEN = "ah_server_token_change_in_production"


def _no_proxy_opener() -> urllib.request.OpenerDirector:
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def _health() -> dict | None:
    try:
        req = urllib.request.Request(f"{BASE}/health")
        with _no_proxy_opener().open(req, timeout=3) as r:
            return json.loads(r.read().decode())
    except (OSError, urllib.error.URLError, json.JSONDecodeError):
        return None


@pytest.fixture(scope="module")
def server_reachable() -> None:
    h = _health()
    if not h or h.get("status") != "ok":
        pytest.skip(
            "127.0.0.1:8080 无 healthy 响应；请先启动: .venv/bin/python server/main_v2.py"
        )


def test_health_json_shape(server_reachable: None) -> None:
    h = _health()
    assert h is not None
    assert h.get("status") == "ok"
    assert "version" in h
    assert "connected_devices" in h


def test_devices_api_unauthorized_without_token(server_reachable: None) -> None:
    req = urllib.request.Request(f"{BASE}/api/v1/devices")
    with pytest.raises(urllib.error.HTTPError) as ei:
        _no_proxy_opener().open(req, timeout=5)
    assert ei.value.code in (401, 403)


def test_devices_api_with_bearer(server_reachable: None) -> None:
    req = urllib.request.Request(
        f"{BASE}/api/v1/devices",
        headers={"Authorization": f"Bearer {TOKEN}"},
    )
    with _no_proxy_opener().open(req, timeout=5) as r:
        body = json.loads(r.read().decode())
    assert body.get("code") == 0
    assert "devices" in body
    assert isinstance(body["devices"], list)
