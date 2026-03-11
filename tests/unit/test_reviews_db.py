from __future__ import annotations

from pathlib import Path

from api.procedures.reviews_db import (
    cleanup_show_review_history_reviews,
    create_project,
    delete_project,
    ensure_app_for_play,
    get_connection,
    get_feature_request_reviews,
    get_project,
    get_project_app_ids,
    insert_review,
    list_projects,
    remove_duplicate_reviews,
    set_project_apps,
    set_review_pinned,
    update_app_metadata,
    update_project,
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


def test_update_app_metadata(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(
        conn,
        play_store_id="com.example.app",
        app_name="Example App",
        play_store_url="https://play.google.com/store/apps/details?id=com.example.app",
    )
    update_app_metadata(
        conn,
        "com.example.app",
        icon_path="/static/icon.png",
        download_count="1M+",
        total_reviews="10K",
        description="An example app",
        screenshots=["https://example.com/1.png"],
    )
    cur = conn.execute(
        "SELECT icon_path, download_count, total_reviews, description, screenshots FROM apps WHERE id = ?",
        (app_pk,),
    )
    row = cur.fetchone()
    conn.close()
    assert row["icon_path"] == "/static/icon.png"
    assert row["download_count"] == "1M+"
    assert row["total_reviews"] == "10K"
    assert "example app" in (row["description"] or "")
    assert "1.png" in (row["screenshots"] or "")


def test_update_app_metadata_no_updates_when_empty(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    ensure_app_for_play(conn, play_store_id="com.example.app", app_name="Example App")
    update_app_metadata(conn, "com.example.app")
    conn.close()


def test_remove_duplicate_reviews_dedupes_and_removes_junk(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(conn, play_store_id="com.example.app", app_name="Example App")
    insert_review(conn, app_pk=app_pk, rating=5, title="", content="Same review content here.", author="A")
    insert_review(conn, app_pk=app_pk, rating=4, title="", content="Same review content here.", author="A")
    insert_review(
        conn,
        app_pk=app_pk,
        rating=1,
        title="",
        content="iPhone iPad Mac Vision Watch TV",
        author="X",
    )
    deleted = remove_duplicate_reviews(conn)
    conn.close()
    assert deleted >= 1


def test_cleanup_show_review_history_deletes_placeholder_only(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(conn, play_store_id="com.example.app", app_name="Example App")
    insert_review(
        conn,
        app_pk=app_pk,
        rating=5,
        title="",
        content="Show review history\nAugust 7, 2024",
        author="",
    )
    result = cleanup_show_review_history_reviews(conn, app_pk=app_pk)
    conn.close()
    assert result["deleted"] == 1
    assert result["updated"] == 0


def test_cleanup_show_review_history_updates_trailing_content(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(conn, play_store_id="com.example.app", app_name="Example App")
    insert_review(
        conn,
        app_pk=app_pk,
        rating=5,
        title="",
        content="Show review history\nMay 1, 2024\n\nSpiritual elevation app. Awesome.",
        author="User",
    )
    result = cleanup_show_review_history_reviews(conn, app_pk=app_pk)
    conn.close()
    assert result["updated"] == 1 or result["deleted"] == 1


def test_set_review_pinned(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(conn, play_store_id="com.example.app", app_name="Example App")
    insert_review(conn, app_pk=app_pk, rating=5, title="", content="Pin me.", author="")
    cur = conn.execute("SELECT id FROM reviews WHERE app_id = ?", (app_pk,))
    review_id = cur.fetchone()["id"]
    ok = set_review_pinned(conn, review_id, True)
    conn.close()
    assert ok is True


def test_set_review_pinned_false_for_missing_returns_false(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    ok = set_review_pinned(conn, 99999, False)
    conn.close()
    assert ok is False


def test_list_projects_empty(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    projects = list_projects(conn)
    conn.close()
    assert projects == []


def test_create_project_and_get_project(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    created = create_project(conn, "My Project", description="Desc", icon=None)
    assert "id" in created
    assert created["name"] == "My Project"
    assert created["description"] == "Desc"
    fetched = get_project(conn, created["id"])
    conn.close()
    assert fetched is not None
    assert fetched["name"] == "My Project"


def test_get_project_returns_none_for_missing(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    project = get_project(conn, 99999)
    conn.close()
    assert project is None


def test_update_project_no_fields_returns_current(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    created = create_project(conn, "Original")
    updated = update_project(conn, created["id"], name=None, description=None, icon=None)
    conn.close()
    assert updated is not None
    assert updated["name"] == "Original"


def test_update_project_with_fields(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    created = create_project(conn, "Original")
    updated = update_project(
        conn,
        created["id"],
        name="Updated",
        description="New desc",
        icon="icon.png",
    )
    conn.close()
    assert updated is not None
    assert updated["name"] == "Updated"
    assert updated["description"] == "New desc"


def test_update_project_returns_none_for_missing(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    result = update_project(conn, 99999, name="X")
    conn.close()
    assert result is None


def test_delete_project(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    created = create_project(conn, "To Delete")
    ok = delete_project(conn, created["id"])
    conn.close()
    assert ok is True


def test_delete_project_false_for_missing(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    ok = delete_project(conn, 99999)
    conn.close()
    assert ok is False


def test_get_project_app_ids_and_set_project_apps(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(conn, play_store_id="com.a.app", app_name="A")
    proj = create_project(conn, "P1")
    set_project_apps(conn, proj["id"], [app_pk])
    ids = get_project_app_ids(conn, proj["id"])
    conn.close()
    assert ids == [app_pk]


def test_get_feature_request_reviews_filter_by_project_id(tmp_path: Path) -> None:
    conn = get_connection(tmp_path / "reviews.db")
    app_pk = ensure_app_for_play(conn, play_store_id="com.example.app", app_name="Example App")
    insert_review(
        conn,
        app_pk=app_pk,
        rating=5,
        title="",
        content="Please add export to PDF.",
        author="User",
        has_feature_request=True,
    )
    proj = create_project(conn, "P1")
    set_project_apps(conn, proj["id"], [app_pk])
    rows = get_feature_request_reviews(conn, project_id=proj["id"])
    conn.close()
    assert len(rows) == 1
    assert rows[0]["has_feature_request"] == 1
