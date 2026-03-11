from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from api.main import app
from api.procedures import reviews_db
from api.procedures.reviews_db import ensure_app_for_play, get_connection, insert_review


@pytest.fixture()
def db_path(tmp_path: Path) -> Path:
    path = tmp_path / "test.db"
    conn = get_connection(path)
    conn.close()
    return path


@pytest.fixture()
def client(db_path: Path, monkeypatch: pytest.MonkeyPatch) -> TestClient:
    from api.routes import apps, reviews, scrape

    def _open_connection() -> sqlite3.Connection:
        conn = sqlite3.connect(str(db_path), check_same_thread=False)
        conn.row_factory = sqlite3.Row
        reviews_db._init_schema(conn)
        return conn

    app.dependency_overrides[apps.get_db_connection] = _open_connection
    app.dependency_overrides[reviews.get_db_connection] = _open_connection
    monkeypatch.setattr(scrape, "get_db_path", lambda: db_path)

    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture()
def seed_db(db_path: Path) -> dict[str, str | int]:
    conn = get_connection(db_path)
    app_pk = ensure_app_for_play(
        conn,
        play_store_id="com.test.app",
        app_name="Test App",
        play_store_url="https://play.google.com/store/apps/details?id=com.test.app",
    )
    insert_review(
        conn,
        app_pk=app_pk,
        rating=5,
        title="Great app",
        content="Great app with a feature request: could you add a dark mode?",
        author="User One",
        review_date="2026-01-01",
        has_feature_request=True,
        platform="Google Play",
    )
    insert_review(
        conn,
        app_pk=app_pk,
        rating=4,
        title="Solid",
        content="Great app and smooth UX overall.",
        author="User Two",
        review_date="2026-01-02",
        has_feature_request=False,
        platform="Google Play",
    )
    conn.close()
    return {"app_id": "com.test.app", "app_pk": app_pk}


@pytest.fixture(autouse=True)
def reset_scrape_state() -> None:
    from api.routes import scrape

    scrape.scrape_jobs.clear()
    scrape.latest_job_id = None
