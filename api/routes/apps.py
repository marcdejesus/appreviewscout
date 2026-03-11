from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from api.config import get_db_path
from api.procedures.reviews_db import get_connection


router = APIRouter(tags=["apps"])


class AddPlayAppRequest(BaseModel):
    url: str = Field(min_length=1)
    download_screenshots: bool = False


def _to_json_safe(row: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in row.items():
        if isinstance(value, Path):
            out[key] = str(value)
            continue
        out[key] = value
    return out


def get_db_connection() -> sqlite3.Connection:
    return get_connection(get_db_path())


@router.get("/apps")
async def list_apps(
    project_id: int | None = None,
    conn: sqlite3.Connection = Depends(get_db_connection),
) -> list[dict[str, Any]]:
    try:
        if project_id is not None:
            cur = conn.execute(
                """SELECT a.* FROM apps a
                   JOIN app_projects ap ON a.id = ap.app_id
                   WHERE ap.project_id = ?
                   ORDER BY a.app_name""",
                (project_id,),
            )
        else:
            cur = conn.execute("SELECT * FROM apps ORDER BY app_name")
        return [_to_json_safe(dict(row)) for row in cur.fetchall()]
    finally:
        conn.close()


@router.post("/apps/play")
async def create_play_app(body: AddPlayAppRequest) -> dict[str, Any]:
    try:
        from api.procedures.add_play_app import add_play_app

        return add_play_app(
            body.url,
            db_path=get_db_path(),
            download_screenshots=body.download_screenshots,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Failed to add Play Store app") from exc
