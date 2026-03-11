from __future__ import annotations

import sys
import types


def test_list_apps_returns_empty_array_when_no_data(client) -> None:
    response = client.get("/apps")

    assert response.status_code == 200
    assert response.json() == []


def test_list_apps_returns_seeded_app(client, seed_db) -> None:
    response = client.get("/apps")

    assert response.status_code == 200
    rows = response.json()
    assert len(rows) == 1
    assert rows[0]["app_name"] == "Test App"


def test_list_apps_filtered_by_project_id_returns_only_project_apps(
    client, seed_db
) -> None:
    app_pk = seed_db["app_pk"]
    create_resp = client.post(
        "/projects",
        json={"name": "P1", "app_ids": [app_pk]},
    )
    assert create_resp.status_code == 200
    project_id = create_resp.json()["id"]

    response = client.get("/apps", params={"project_id": project_id})
    assert response.status_code == 200
    rows = response.json()
    assert len(rows) == 1
    assert rows[0]["id"] == app_pk


def test_list_apps_with_project_id_empty_when_no_apps_in_project(client, seed_db) -> None:
    create_resp = client.post("/projects", json={"name": "Empty Project", "app_ids": []})
    assert create_resp.status_code == 200
    project_id = create_resp.json()["id"]

    response = client.get("/apps", params={"project_id": project_id})
    assert response.status_code == 200
    assert response.json() == []


def test_create_play_app_returns_mocked_success(client, monkeypatch) -> None:
    fake_module = types.ModuleType("api.procedures.add_play_app")
    fake_module.add_play_app = lambda url, db_path=None, download_screenshots=False: {
        "app_name": "Mock App",
        "play_store_id": "com.mock.app",
        "icon_path": None,
        "download_count": "1M+",
        "total_reviews": "10K",
        "screenshots_count": 0,
    }
    monkeypatch.setitem(sys.modules, "api.procedures.add_play_app", fake_module)

    response = client.post(
        "/apps/play",
        json={
            "url": "https://play.google.com/store/apps/details?id=com.mock.app",
            "download_screenshots": False,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["app_name"] == "Mock App"
    assert body["play_store_id"] == "com.mock.app"


def test_create_play_app_returns_422_for_invalid_body(client) -> None:
    response = client.post("/apps/play", json={})

    assert response.status_code == 422


def test_create_play_app_returns_400_for_value_error(client, monkeypatch) -> None:
    def _raise_value_error(url, db_path=None, download_screenshots=False):  # type: ignore[no-untyped-def]
        raise ValueError("Invalid Play Store URL")

    fake_module = types.ModuleType("api.procedures.add_play_app")
    fake_module.add_play_app = _raise_value_error
    monkeypatch.setitem(sys.modules, "api.procedures.add_play_app", fake_module)

    response = client.post(
        "/apps/play",
        json={"url": "https://play.google.com/store/apps/details?id=bad"},
    )

    assert response.status_code == 400
    assert "Invalid Play Store URL" in response.json()["detail"]


def test_create_play_app_returns_500_for_unexpected_error(client, monkeypatch) -> None:
    def _raise_runtime_error(url, db_path=None, download_screenshots=False):  # type: ignore[no-untyped-def]
        raise RuntimeError("unexpected failure")

    fake_module = types.ModuleType("api.procedures.add_play_app")
    fake_module.add_play_app = _raise_runtime_error
    monkeypatch.setitem(sys.modules, "api.procedures.add_play_app", fake_module)

    response = client.post(
        "/apps/play",
        json={"url": "https://play.google.com/store/apps/details?id=com.fail"},
    )

    assert response.status_code == 500
    assert response.json()["detail"] == "Failed to add Play Store app"
