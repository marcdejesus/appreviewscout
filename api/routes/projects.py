from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from api.config import get_db_path
from api.procedures.reviews_db import (
    create_project,
    delete_project,
    get_project,
    get_project_app_ids,
    list_projects,
    set_project_apps,
    update_project,
)
from api.routes.apps import get_db_connection

router = APIRouter(tags=["projects"])


class CreateProjectRequest(BaseModel):
    name: str
    description: str | None = None
    icon: str | None = None
    app_ids: list[int] | None = None


class UpdateProjectRequest(BaseModel):
    name: str | None = None
    description: str | None = None
    icon: str | None = None
    app_ids: list[int] | None = None


def _project_to_json(project: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in project.items():
        if isinstance(value, Path):
            out[key] = str(value)
            continue
        out[key] = value
    return out


@router.get("/projects")
async def list_projects_route(conn: sqlite3.Connection = Depends(get_db_connection)) -> list[dict[str, Any]]:
    try:
        projects = list_projects(conn)
        return [_project_to_json(p) for p in projects]
    finally:
        conn.close()


@router.get("/projects/{project_id}")
async def get_project_route(
    project_id: int,
    conn: sqlite3.Connection = Depends(get_db_connection),
) -> dict[str, Any]:
    try:
        project = get_project(conn, project_id)
        if project is None:
            raise HTTPException(status_code=404, detail="Project not found")
        out = _project_to_json(project)
        out["app_ids"] = get_project_app_ids(conn, project_id)
        return out
    finally:
        conn.close()


@router.post("/projects")
async def create_project_route(
    body: CreateProjectRequest,
    conn: sqlite3.Connection = Depends(get_db_connection),
) -> dict[str, Any]:
    try:
        name = body.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="name is required")
        project = create_project(conn, name, body.description, body.icon)
        if body.app_ids:
            set_project_apps(conn, project["id"], body.app_ids)
        out = _project_to_json(project)
        out["app_ids"] = get_project_app_ids(conn, project["id"])
        return out
    finally:
        conn.close()


@router.patch("/projects/{project_id}")
async def update_project_route(
    project_id: int,
    body: UpdateProjectRequest,
    conn: sqlite3.Connection = Depends(get_db_connection),
) -> dict[str, Any]:
    try:
        project = get_project(conn, project_id)
        if project is None:
            raise HTTPException(status_code=404, detail="Project not found")
        name = body.name.strip() if body.name and body.name.strip() else None
        if body.name is not None and not name:
            raise HTTPException(status_code=400, detail="name must be a non-empty string")
        updated = update_project(
            conn,
            project_id,
            name=name,
            description=body.description,
            icon=body.icon,
        )
        if body.app_ids is not None:
            set_project_apps(conn, project_id, body.app_ids)
        out = _project_to_json(updated or project)
        out["app_ids"] = get_project_app_ids(conn, project_id)
        return out
    finally:
        conn.close()


@router.delete("/projects/{project_id}")
async def delete_project_route(
    project_id: int,
    conn: sqlite3.Connection = Depends(get_db_connection),
) -> dict[str, Any]:
    try:
        if not delete_project(conn, project_id):
            raise HTTPException(status_code=404, detail="Project not found")
        return {"id": project_id, "deleted": True}
    finally:
        conn.close()
