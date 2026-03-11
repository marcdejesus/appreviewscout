"""
SQLite storage for Google Play review data.
Stores rating, content, and flags reviews that contain feature requests for market research.
"""

import json
import re
import sqlite3
import hashlib
from pathlib import Path
from typing import Any, Optional

DEFAULT_DB_PATH = Path(__file__).resolve().parent.parent / "data" / "app_store_reviews.db"


def get_connection(db_path: Optional[Path] = None) -> sqlite3.Connection:
    """Return a connection to the reviews database, creating the file and schema if needed."""
    path = db_path or DEFAULT_DB_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    _init_schema(conn)
    return conn


def _init_schema(conn: sqlite3.Connection) -> None:
    """Create tables if they do not exist."""
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS apps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_id TEXT NOT NULL UNIQUE,
            app_name TEXT NOT NULL,
            play_store_id TEXT,
            play_store_url TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_id INTEGER NOT NULL,
            source_id TEXT NOT NULL,
            content_hash TEXT,
            platform TEXT NOT NULL DEFAULT 'Google Play',
            rating INTEGER,
            title TEXT,
            content TEXT NOT NULL,
            author TEXT,
            review_date TEXT,
            has_feature_request INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            UNIQUE(app_id, source_id, platform),
            FOREIGN KEY (app_id) REFERENCES apps(id)
        );

        CREATE INDEX IF NOT EXISTS idx_reviews_app_id ON reviews(app_id);
        CREATE INDEX IF NOT EXISTS idx_reviews_has_feature_request ON reviews(has_feature_request);
        CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
    """)
    _ensure_content_hash_column(conn)
    _ensure_platform_column(conn)
    _ensure_apps_play_columns(conn)
    _ensure_apps_metadata_columns(conn)
    _ensure_pinned_column(conn)
    _ensure_projects_tables(conn)
    _migrate_remove_app_store(conn)
    _remove_duplicate_reviews_by_content(conn)
    conn.execute("DROP INDEX IF EXISTS idx_reviews_app_content_hash")
    conn.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_app_content_hash ON reviews(app_id, content_hash, COALESCE(platform, 'Google Play'))"
    )
    conn.commit()


def _ensure_platform_column(conn: sqlite3.Connection) -> None:
    """Add platform column if missing (migration)."""
    cur = conn.execute("PRAGMA table_info(reviews)")
    columns = [row[1] for row in cur.fetchall()]
    if "platform" not in columns:
        conn.execute("ALTER TABLE reviews ADD COLUMN platform TEXT NOT NULL DEFAULT 'Google Play'")
        conn.execute("DROP INDEX IF EXISTS idx_reviews_app_content_hash")


def _ensure_apps_play_columns(conn: sqlite3.Connection) -> None:
    """Add play_store_id and play_store_url to apps if missing (migration)."""
    cur = conn.execute("PRAGMA table_info(apps)")
    columns = [row[1] for row in cur.fetchall()]
    if "play_store_id" not in columns:
        conn.execute("ALTER TABLE apps ADD COLUMN play_store_id TEXT")
    if "play_store_url" not in columns:
        conn.execute("ALTER TABLE apps ADD COLUMN play_store_url TEXT")


def _ensure_apps_metadata_columns(conn: sqlite3.Connection) -> None:
    """Add icon_path, download_count, total_reviews, description, screenshots to apps if missing (migration)."""
    cur = conn.execute("PRAGMA table_info(apps)")
    columns = [row[1] for row in cur.fetchall()]
    for col, col_type in [
        ("icon_path", "TEXT"),
        ("download_count", "TEXT"),
        ("total_reviews", "TEXT"),
        ("description", "TEXT"),
        ("screenshots", "TEXT"),
    ]:
        if col not in columns:
            conn.execute(f"ALTER TABLE apps ADD COLUMN {col} {col_type}")


def _ensure_pinned_column(conn: sqlite3.Connection) -> None:
    """Add pinned column to reviews if missing (migration). Default False."""
    cur = conn.execute("PRAGMA table_info(reviews)")
    columns = [row[1] for row in cur.fetchall()]
    if "pinned" not in columns:
        conn.execute("ALTER TABLE reviews ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_reviews_pinned ON reviews(pinned)")


def _ensure_projects_tables(conn: sqlite3.Connection) -> None:
    """Create projects and app_projects tables if missing (migration)."""
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            icon TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS app_projects (
            app_id INTEGER NOT NULL,
            project_id INTEGER NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            PRIMARY KEY (app_id, project_id),
            FOREIGN KEY (app_id) REFERENCES apps(id),
            FOREIGN KEY (project_id) REFERENCES projects(id)
        );
    """)


def _ensure_content_hash_column(conn: sqlite3.Connection) -> None:
    """Add content_hash column if missing and backfill (migration)."""
    cur = conn.execute("PRAGMA table_info(reviews)")
    columns = [row[1] for row in cur.fetchall()]
    if "content_hash" not in columns:
        conn.execute("ALTER TABLE reviews ADD COLUMN content_hash TEXT")
    # Backfill content_hash for rows that have none
    cur = conn.execute("SELECT id, content, COALESCE(author, '') FROM reviews WHERE content_hash IS NULL OR content_hash = ''")
    for row in cur.fetchall():
        c_hash = _content_hash(row[1], row[2])
        conn.execute("UPDATE reviews SET content_hash = ? WHERE id = ?", (c_hash, row[0]))


def _recompute_content_hashes_normalized(conn: sqlite3.Connection) -> None:
    """Recompute content_hash for every row using normalized content (date/author prefix stripped)."""
    cur = conn.execute("SELECT id, content, COALESCE(author, '') FROM reviews")
    for row in cur.fetchall():
        c_hash = _content_hash(row[1], row[2])
        conn.execute("UPDATE reviews SET content_hash = ? WHERE id = ?", (c_hash, row[0]))


def _remove_duplicate_reviews_by_content(conn: sqlite3.Connection) -> None:
    """Delete duplicate rows with same (app_id, content_hash, platform), keeping the row with smallest id."""
    conn.execute("""
        DELETE FROM reviews
        WHERE content_hash IS NOT NULL
          AND id NOT IN (
            SELECT MIN(id) FROM reviews
            WHERE content_hash IS NOT NULL
            GROUP BY app_id, content_hash, COALESCE(platform, 'Google Play')
          )
    """)
    conn.commit()


def _source_id(content: str, title: str = "", author: str = "") -> str:
    """Generate a stable id for deduplication (includes title/author)."""
    raw = f"{title}|{content[:500]}|{author}"
    return hashlib.sha256(raw.encode("utf-8", errors="replace")).hexdigest()[:32]


# Leading date pattern (e.g. "12/21/2025 ", "Jan 4 ", "Jan 21 ")
_LEADING_DATE_RE = re.compile(
    r"^\s*(?:\d{1,2}/\d{1,2}/\d{2,4}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2})\s*",
    re.IGNORECASE,
)


def _normalize_content_for_dedup(content: str, author: str = "") -> str:
    """
    Normalize content so that "12/21/2025 Kelbellooo I absolutely love..." and
    "I absolutely love..." hash the same. Strips leading date and optional author prefix.
    """
    s = content.strip()
    # Strip leading date
    s = _LEADING_DATE_RE.sub("", s, count=1).strip()
    # Strip leading author name if present (same as stored author)
    if author and s.startswith(author):
        s = s[len(author) :].strip()
    return s


def _content_hash(content: str, author: str = "") -> str:
    """Hash of normalized content; same review with date/author prefix hashes the same."""
    normalized = _normalize_content_for_dedup(content, author).encode("utf-8", errors="replace")
    return hashlib.sha256(normalized).hexdigest()


def _migrate_remove_app_store(conn: sqlite3.Connection) -> None:
    """
    One-time migration: remove App Store data and columns.
    Deletes reviews where platform = 'App Store', deletes apps with no play_store_id,
    and drops store_url from apps if present. Play Store data is left unchanged.
    """
    conn.execute("DELETE FROM reviews WHERE platform = 'App Store'")
    conn.execute("DELETE FROM apps WHERE play_store_id IS NULL")
    cur = conn.execute("PRAGMA table_info(apps)")
    columns = [row[1] for row in cur.fetchall()]
    if "store_url" not in columns:
        conn.commit()
        return
    # Recreate apps table without store_url (SQLite has no DROP COLUMN in older versions)
    conn.execute("DROP INDEX IF EXISTS idx_reviews_app_content_hash")
    conn.execute("""
        CREATE TABLE apps_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_id TEXT NOT NULL UNIQUE,
            app_name TEXT NOT NULL,
            play_store_id TEXT,
            play_store_url TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            icon_path TEXT,
            download_count TEXT,
            total_reviews TEXT,
            description TEXT,
            screenshots TEXT
        )
    """)
    conn.execute("""
        INSERT INTO apps_new (id, app_id, app_name, play_store_id, play_store_url, created_at, icon_path, download_count, total_reviews, description, screenshots)
        SELECT id, app_id, app_name, play_store_id, play_store_url, created_at, icon_path, download_count, total_reviews, description, screenshots FROM apps
    """)
    conn.execute("DROP TABLE apps")
    conn.execute("ALTER TABLE apps_new RENAME TO apps")
    conn.commit()


def ensure_app_for_play(
    conn: sqlite3.Connection,
    play_store_id: str,
    app_name: str,
    play_store_url: str = "",
) -> int:
    """Get or create app row for Google Play; return apps.id."""
    cur = conn.execute("SELECT id FROM apps WHERE play_store_id = ?", (play_store_id,))
    row = cur.fetchone()
    if row:
        return row["id"]
    conn.execute(
        "INSERT INTO apps (app_id, app_name, play_store_id, play_store_url) VALUES (?, ?, ?, ?)",
        (play_store_id, app_name, play_store_id, play_store_url or ""),
    )
    conn.commit()
    cur = conn.execute("SELECT id FROM apps WHERE play_store_id = ?", (play_store_id,))
    return cur.fetchone()["id"]


def update_app_metadata(
    conn: sqlite3.Connection,
    play_store_id: str,
    *,
    icon_path: Optional[str] = None,
    download_count: Optional[str] = None,
    total_reviews: Optional[str] = None,
    description: Optional[str] = None,
    screenshots: Optional[Any] = None,
) -> None:
    """
    Update app row with Play Store metadata. Row must exist (create via ensure_app_for_play first).
    screenshots: JSON-serializable list (e.g. of URLs or dicts with path/url); stored as TEXT.
    """
    updates: list[str] = []
    params: list[Any] = []
    if icon_path is not None:
        updates.append("icon_path = ?")
        params.append(icon_path)
    if download_count is not None:
        updates.append("download_count = ?")
        params.append(download_count)
    if total_reviews is not None:
        updates.append("total_reviews = ?")
        params.append(total_reviews)
    if description is not None:
        # Cap length for SQLite / display; 50k chars is plenty
        desc = description[:50000] if len(description) > 50000 else description
        updates.append("description = ?")
        params.append(desc)
    if screenshots is not None:
        updates.append("screenshots = ?")
        params.append(json.dumps(screenshots) if not isinstance(screenshots, str) else screenshots)
    if not updates:
        return
    params.append(play_store_id)
    conn.execute(
        f"UPDATE apps SET {', '.join(updates)} WHERE play_store_id = ?",
        params,
    )
    conn.commit()


def insert_review(
    conn: sqlite3.Connection,
    app_pk: int,
    rating: Optional[int],
    title: str,
    content: str,
    author: str = "",
    review_date: str = "",
    has_feature_request: bool = False,
    platform: str = "Google Play",
) -> bool:
    """Insert or ignore a review. Returns True if inserted, False if duplicate. platform: 'Google Play'."""
    source_id = _source_id(content, title, author)
    content_hash = _content_hash(content, author or "")
    platform = platform or "Google Play"
    try:
        conn.execute(
            """INSERT INTO reviews (app_id, source_id, content_hash, platform, rating, title, content, author, review_date, has_feature_request)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                app_pk,
                source_id,
                content_hash,
                platform,
                rating,
                title or "",
                content,
                author or "",
                review_date or "",
                1 if has_feature_request else 0,
            ),
        )
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        conn.rollback()
        return False


def remove_duplicate_reviews(conn: sqlite3.Connection) -> int:
    """
    Recompute content_hash using normalized content (so "DATE AUTHOR text" and "text" match),
    then remove duplicate reviews (same app_id + content_hash), keeping the earliest by id.
    Also removes obvious junk rows (e.g. platform names). Returns number of rows deleted.
    """
    before = conn.execute("SELECT COUNT(*) FROM reviews").fetchone()[0]
    _ensure_content_hash_column(conn)
    # Drop unique index so we can have duplicate content_hash while we recompute
    conn.execute("DROP INDEX IF EXISTS idx_reviews_app_content_hash")
    _recompute_content_hashes_normalized(conn)
    _remove_duplicate_reviews_by_content(conn)
    _remove_junk_reviews(conn)
    conn.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_app_content_hash ON reviews(app_id, content_hash)"
    )
    conn.commit()
    after = conn.execute("SELECT COUNT(*) FROM reviews").fetchone()[0]
    return before - after


def _remove_junk_reviews(conn: sqlite3.Connection) -> None:
    """Remove rows that are clearly not reviews (e.g. 'iPhone iPad Mac Vision Watch TV')."""
    conn.execute("""
        DELETE FROM reviews
        WHERE LENGTH(TRIM(content)) < 30
           OR content LIKE '%iPhone iPad Mac Vision Watch TV%'
    """)


# Month names for "Show review history [Month DD, YYYY]" date line (non-capturing group so \s+ applies)
_SHOW_HISTORY_MONTHS = (
    r"(?:January|February|March|April|May|June|July|August|September|October|November|December)"
)
# Content that is only "Show review history" + optional whitespace + single date line
_SHOW_HISTORY_ONLY_RE = re.compile(
    rf"\A\s*show\s+review\s+history\s*\n?\s*{_SHOW_HISTORY_MONTHS}\s+\d{{1,2}},\s*\d{{4}}\s*\Z",
    re.IGNORECASE,
)
# Content that has "Show review history" + date line + trailing content (capture group 1 = trailing)
_SHOW_HISTORY_WITH_TRAILING_RE = re.compile(
    rf"\A\s*show\s+review\s+history\s*\n?\s*{_SHOW_HISTORY_MONTHS}\s+\d{{1,2}},\s*\d{{4}}\s*\n+\s*(.+\Z)",
    re.IGNORECASE | re.DOTALL,
)


def cleanup_show_review_history_reviews(
    conn: sqlite3.Connection,
    app_pk: Optional[int] = None,
) -> dict[str, int]:
    """
    Run after a scrape to clean Play Store placeholder content.

    - Delete reviews whose content is only "Show review history" plus a date line
      (e.g. "Show review history\\nAugust 7, 2024").
    - For reviews that have trailing content after that (e.g. "Show review history\\nMay 1, 2024\\nSpiritual elevation app. Awesome"),
      update content to just the trailing part.

    If app_pk is set, only process reviews for that app; otherwise process all reviews.
    Returns dict with "deleted" and "updated" counts.
    """
    deleted = 0
    updated = 0
    if app_pk is not None:
        cur = conn.execute(
            "SELECT id, content, author, title FROM reviews WHERE app_id = ?",
            (app_pk,),
        )
    else:
        cur = conn.execute("SELECT id, content, author, title FROM reviews")
    rows = cur.fetchall()
    to_delete: list[int] = []
    to_update: list[tuple[str, str, str, int]] = []  # (new_content, author, title, id)
    for row in rows:
        content = row["content"] or ""
        if "show review history" not in content.lower():
            continue
        if _SHOW_HISTORY_ONLY_RE.match(content.strip()):
            to_delete.append(row["id"])
            continue
        match = _SHOW_HISTORY_WITH_TRAILING_RE.match(content)
        if match:
            new_content = match.group(1).strip()
            if new_content:
                to_update.append((new_content, row["author"] or "", row["title"] or "", row["id"]))
    for rid in to_delete:
        conn.execute("DELETE FROM reviews WHERE id = ?", (rid,))
        deleted += 1
    for new_content, author, title, rid in to_update:
        new_source_id = _source_id(new_content, title, author)
        new_content_hash = _content_hash(new_content, author)
        conn.execute("SAVEPOINT cleanup_one")
        try:
            conn.execute(
                "UPDATE reviews SET content = ?, source_id = ?, content_hash = ? WHERE id = ?",
                (new_content, new_source_id, new_content_hash, rid),
            )
            updated += 1
        except sqlite3.IntegrityError:
            conn.execute("ROLLBACK TO SAVEPOINT cleanup_one")
            conn.execute("DELETE FROM reviews WHERE id = ?", (rid,))
            deleted += 1
        conn.execute("RELEASE SAVEPOINT cleanup_one")
    if to_delete or to_update:
        conn.commit()
    return {"deleted": deleted, "updated": updated}


def set_review_pinned(
    conn: sqlite3.Connection,
    review_id: int,
    pinned: bool,
) -> bool:
    """Set pinned flag for a review by id. Returns True if a row was updated."""
    cur = conn.execute(
        "UPDATE reviews SET pinned = ? WHERE id = ?",
        (1 if pinned else 0, review_id),
    )
    conn.commit()
    return cur.rowcount > 0


def get_feature_request_reviews(
    conn: sqlite3.Connection,
    app_store_id: Optional[str] = None,
    platform: Optional[str] = None,
    project_id: Optional[int] = None,
) -> list[dict]:
    """Return all reviews flagged as containing feature requests. Filter by app (play_store_id / app_id), platform (e.g. 'Google Play'), and/or project_id."""
    conditions = ["r.has_feature_request = 1"]
    params: list = []
    if app_store_id:
        conditions.append("a.app_id = ?")
        params.append(app_store_id)
    if platform:
        conditions.append("r.platform = ?")
        params.append(platform)
    if project_id is not None:
        conditions.append("a.id IN (SELECT app_id FROM app_projects WHERE project_id = ?)")
        params.append(project_id)
    where = " AND ".join(conditions)
    cur = conn.execute(
        f"""SELECT r.*, a.app_id AS store_app_id, a.app_name
            FROM reviews r JOIN apps a ON r.app_id = a.id
            WHERE {where}
            ORDER BY r.created_at DESC""",
        tuple(params),
    )
    return [dict(r) for r in cur.fetchall()]


# --- Projects ---


def list_projects(conn: sqlite3.Connection) -> list[dict]:
    """Return all projects as list of dicts (id, name, description, icon, created_at)."""
    cur = conn.execute(
        "SELECT id, name, description, icon, created_at FROM projects ORDER BY name"
    )
    return [dict(row) for row in cur.fetchall()]


def get_project(conn: sqlite3.Connection, project_id: int) -> Optional[dict]:
    """Return a single project by id or None."""
    cur = conn.execute(
        "SELECT id, name, description, icon, created_at FROM projects WHERE id = ?",
        (project_id,),
    )
    row = cur.fetchone()
    return dict(row) if row else None


def create_project(
    conn: sqlite3.Connection,
    name: str,
    description: Optional[str] = None,
    icon: Optional[str] = None,
) -> dict:
    """Create a project and return its dict (with id)."""
    conn.execute(
        "INSERT INTO projects (name, description, icon) VALUES (?, ?, ?)",
        (name, description or None, icon or None),
    )
    conn.commit()
    cur = conn.execute("SELECT id, name, description, icon, created_at FROM projects ORDER BY id DESC LIMIT 1")
    return dict(cur.fetchone())


def update_project(
    conn: sqlite3.Connection,
    project_id: int,
    name: Optional[str] = None,
    description: Optional[str] = None,
    icon: Optional[str] = None,
) -> Optional[dict]:
    """Update project by id. Pass None for fields to leave unchanged. Returns updated project or None."""
    cur = conn.execute("SELECT id FROM projects WHERE id = ?", (project_id,))
    if cur.fetchone() is None:
        return None
    updates: list[str] = []
    params: list[Any] = []
    if name is not None:
        updates.append("name = ?")
        params.append(name)
    if description is not None:
        updates.append("description = ?")
        params.append(description)
    if icon is not None:
        updates.append("icon = ?")
        params.append(icon)
    if not updates:
        return get_project(conn, project_id)
    params.append(project_id)
    conn.execute(f"UPDATE projects SET {', '.join(updates)} WHERE id = ?", params)
    conn.commit()
    return get_project(conn, project_id)


def delete_project(conn: sqlite3.Connection, project_id: int) -> bool:
    """Delete project and its app_projects rows. Returns True if a project was deleted."""
    conn.execute("DELETE FROM app_projects WHERE project_id = ?", (project_id,))
    cur = conn.execute("DELETE FROM projects WHERE id = ?", (project_id,))
    conn.commit()
    return cur.rowcount > 0


def get_project_app_ids(conn: sqlite3.Connection, project_id: int) -> list[int]:
    """Return list of apps.id for apps in the project."""
    cur = conn.execute(
        "SELECT app_id FROM app_projects WHERE project_id = ? ORDER BY app_id",
        (project_id,),
    )
    return [row["app_id"] for row in cur.fetchall()]


def set_project_apps(conn: sqlite3.Connection, project_id: int, app_ids: list[int]) -> None:
    """Replace project membership: delete existing, insert new rows for each app_id."""
    conn.execute("DELETE FROM app_projects WHERE project_id = ?", (project_id,))
    for app_id in app_ids:
        conn.execute(
            "INSERT OR IGNORE INTO app_projects (app_id, project_id) VALUES (?, ?)",
            (app_id, project_id),
        )
    conn.commit()
