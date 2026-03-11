from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from api.config import get_db_path
from api.procedures.reviews_db import get_connection, get_feature_request_reviews, set_review_pinned


router = APIRouter(tags=["reviews"])


class PinUpdate(BaseModel):
    pinned: bool


# Play Store sometimes yields this as "content" when the real review body isn't scraped
_PLACEHOLDER_CONTENT = "show review history"


def _to_json_safe(row: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in row.items():
        if isinstance(value, Path):
            out[key] = str(value)
            continue
        if key == "content" and isinstance(value, str) and value.strip().lower() == _PLACEHOLDER_CONTENT:
            out[key] = ""
            continue
        out[key] = value
    return out


def get_db_connection() -> sqlite3.Connection:
    return get_connection(get_db_path())


@router.get("/reviews")
async def list_reviews(
    app_id: str | None = None,
    platform: str | None = None,
    project_id: int | None = None,
    feature_request_only: bool = Query(default=False),
    pinned: bool | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    conn: sqlite3.Connection = Depends(get_db_connection),
) -> dict[str, Any]:
    try:
        conditions: list[str] = []
        params: list[Any] = []

        if app_id:
            conditions.append("(a.app_id = ? OR a.play_store_id = ?)")
            params.extend([app_id, app_id])

        if platform:
            conditions.append("r.platform = ?")
            params.append(platform)

        if project_id is not None:
            conditions.append("a.id IN (SELECT app_id FROM app_projects WHERE project_id = ?)")
            params.append(project_id)

        if feature_request_only:
            conditions.append("r.has_feature_request = 1")

        if pinned is not None:
            conditions.append("r.pinned = ?")
            params.append(1 if pinned else 0)

        where_sql = " AND ".join(conditions)
        if where_sql:
            where_sql = f"WHERE {where_sql}"

        count_query = f"""
            SELECT COUNT(*) FROM reviews r
            JOIN apps a ON r.app_id = a.id
            {where_sql}
        """
        total = conn.execute(count_query, tuple(params)).fetchone()[0]

        query = f"""
            SELECT r.*, a.app_id AS store_app_id, a.app_name
            FROM reviews r
            JOIN apps a ON r.app_id = a.id
            {where_sql}
            ORDER BY r.created_at DESC
            LIMIT ? OFFSET ?
        """
        page_params = [*params, limit, offset]
        cur = conn.execute(query, tuple(page_params))
        reviews = [_to_json_safe(dict(row)) for row in cur.fetchall()]
        return {"reviews": reviews, "total": total}
    finally:
        conn.close()


@router.patch("/reviews/{review_id}/pin")
async def update_review_pin(
    review_id: int,
    body: PinUpdate,
    conn: sqlite3.Connection = Depends(get_db_connection),
) -> dict[str, Any]:
    try:
        updated = set_review_pinned(conn, review_id, body.pinned)
        if not updated:
            raise HTTPException(status_code=404, detail="Review not found")
        return {"id": review_id, "pinned": body.pinned}
    finally:
        conn.close()


@router.get("/feature-requests")
async def list_feature_requests(
    app_id: str | None = None,
    platform: str | None = None,
    project_id: int | None = None,
    conn: sqlite3.Connection = Depends(get_db_connection),
) -> list[dict[str, Any]]:
    try:
        rows = get_feature_request_reviews(
            conn,
            app_store_id=app_id,
            platform=platform,
            project_id=project_id,
        )
        return [_to_json_safe(row) for row in rows]
    finally:
        conn.close()
