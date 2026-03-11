from __future__ import annotations

import sys
import types


def _install_fake_scrape_module(monkeypatch) -> None:  # type: ignore[no-untyped-def]
    fake_module = types.ModuleType("api.procedures.scrape_google_play_reviews")

    def fake_resolve(url, db_path):  # type: ignore[no-untyped-def]
        return (url, "com.mock.scrape", "Mock Scrape App")

    def fake_run_scrape(**kwargs):  # type: ignore[no-untyped-def]
        return {
            "reviews_parsed": 5,
            "reviews_inserted": 4,
            "reviews_in_dom": 20,
            "feature_requests_flagged": 1,
            "feature_request_reviews": [],
        }

    fake_module._resolve_url_play_store_id_app_name = fake_resolve
    fake_module.run_scrape = fake_run_scrape
    monkeypatch.setitem(sys.modules, "api.procedures.scrape_google_play_reviews", fake_module)


def test_get_scrape_status_returns_idle_when_no_jobs(client) -> None:
    response = client.get("/scrape/status")

    assert response.status_code == 200
    assert response.json() == {"status": "idle", "job_id": None}


def test_start_scrape_returns_job_id_and_started_status(client, monkeypatch) -> None:
    _install_fake_scrape_module(monkeypatch)

    response = client.post("/scrape/play-store", json={"url": "https://play.google.com/store/apps/details?id=com.mock.scrape"})

    assert response.status_code == 200
    body = response.json()
    assert "job_id" in body
    assert body["status"] == "started"


def test_get_scrape_status_returns_done_for_created_job(client, monkeypatch) -> None:
    _install_fake_scrape_module(monkeypatch)

    create_response = client.post(
        "/scrape/play-store",
        json={"url": "https://play.google.com/store/apps/details?id=com.mock.scrape"},
    )
    job_id = create_response.json()["job_id"]

    status_response = client.get("/scrape/status", params={"job_id": job_id})
    assert status_response.status_code == 200
    body = status_response.json()
    assert body["status"] == "done"
    assert body["job_id"] == job_id
    assert body["result"]["reviews_parsed"] == 5


def test_get_scrape_status_returns_404_for_unknown_job(client) -> None:
    response = client.get("/scrape/status", params={"job_id": "not-found"})

    assert response.status_code == 404
    assert response.json()["detail"] == "Scrape job not found"
