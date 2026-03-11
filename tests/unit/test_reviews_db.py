from __future__ import annotations

from pathlib import Path

from api.procedures.reviews_db import (
    ensure_app_for_play,
    get_connection,
    get_feature_request_reviews,
    insert_review,
)


def test_get_connection_creates_and_reuses_schema(tmp_path: Path) -> None:
    db = tmp_path / "reviews.db"
    conn = get_connection(db)
    conn.close()

    conn2 = get_connection(db)
    apps_exists = conn2.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='apps'"
    ).fetchone()
    reviews_exists = conn2.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='reviews'"
    ).fetchone()
    conn2.close()

    assert apps_exists is not None
    assert reviews_exists is not None


def test_ensure_app_for_play_returns_same_id_for_existing_app(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    first_id = ensure_app_for_play(
        conn,
        play_store_id="com.example.app",
        app_name="Example App",
        play_store_url="https://play.google.com/store/apps/details?id=com.example.app",
    )
    second_id = ensure_app_for_play(
        conn,
        play_store_id="com.example.app",
        app_name="Example App",
        play_store_url="https://play.google.com/store/apps/details?id=com.example.app",
    )
    conn.close()

    assert isinstance(first_id, int)
    assert first_id == second_id


def test_insert_review_deduplicates_same_review(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(
        conn,
        play_store_id="com.example.app",
        app_name="Example App",
    )
    first = insert_review(
        conn,
        app_pk=app_pk,
        rating=5,
        title="Title",
        content="Please add a dark mode setting.",
        author="Author",
        has_feature_request=True,
    )
    second = insert_review(
        conn,
        app_pk=app_pk,
        rating=5,
        title="Title",
        content="Please add a dark mode setting.",
        author="Author",
        has_feature_request=True,
    )
    conn.close()

    assert first is True
    assert second is False


def test_get_feature_request_reviews_filters_by_app_and_platform(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(
        conn,
        play_store_id="com.example.app",
        app_name="Example App",
    )
    insert_review(
        conn,
        app_pk=app_pk,
        rating=5,
        title="",
        content="Could you add export to PDF?",
        author="Author A",
        has_feature_request=True,
        platform="Google Play",
    )
    insert_review(
        conn,
        app_pk=app_pk,
        rating=4,
        title="",
        content="Works great already.",
        author="Author B",
        has_feature_request=False,
        platform="Google Play",
    )

    all_rows = get_feature_request_reviews(conn)
    by_app = get_feature_request_reviews(conn, app_store_id="com.example.app")
    wrong_app = get_feature_request_reviews(conn, app_store_id="com.wrong.app")
    by_platform = get_feature_request_reviews(conn, platform="Google Play")
    conn.close()

    assert len(all_rows) == 1
    assert len(by_app) == 1
    assert len(wrong_app) == 0
    assert len(by_platform) == 1
