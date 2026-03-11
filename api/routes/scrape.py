from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, HTTPException, Query
from pydantic import BaseModel, Field

from api.config import get_db_path


router = APIRouter(tags=["scrape"])

scrape_jobs: dict[str, dict[str, Any]] = {}
latest_job_id: str | None = None
jobs_lock = Lock()
DEFAULT_PLAY_APP_URL = "https://play.google.com/store/apps/details?id=com.hrd.motivation&hl=en_US"
DEFAULT_PLAY_APP_NAME = "Motivation - Daily quotes"
DEFAULT_PLAY_STORE_ID = "com.hrd.motivation"


class ScrapeRequest(BaseModel):
    url: str = Field(default=DEFAULT_PLAY_APP_URL, min_length=1)
    max_scrolls: int = Field(default=50, ge=1)
    scroll_pause_ms: int = Field(default=1500, ge=100)
    min_reviews: int = Field(default=0, ge=0)
    no_browser: bool = False


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _run_scrape_job(job_id: str, body: ScrapeRequest) -> None:
    global latest_job_id

    with jobs_lock:
        job = scrape_jobs[job_id]
        job["status"] = "running"
        job["started_at"] = _utc_now()

    try:
        from api.procedures.scrape_google_play_reviews import (
            _resolve_url_play_store_id_app_name,
            run_scrape,
        )

        url, play_store_id, app_name = _resolve_url_play_store_id_app_name(
            body.url,
            get_db_path(),
        )
        result = run_scrape(
            url=url,
            play_store_id=play_store_id or DEFAULT_PLAY_STORE_ID,
            app_name=app_name or DEFAULT_PLAY_APP_NAME,
            max_scrolls=body.max_scrolls,
            scroll_pause_ms=body.scroll_pause_ms,
            min_reviews=body.min_reviews,
            db_path=get_db_path(),
            no_browser=body.no_browser,
        )
        with jobs_lock:
            scrape_jobs[job_id]["status"] = "done"
            scrape_jobs[job_id]["result"] = result
            scrape_jobs[job_id]["finished_at"] = _utc_now()
            latest_job_id = job_id
    except Exception as exc:
        with jobs_lock:
            scrape_jobs[job_id]["status"] = "failed"
            scrape_jobs[job_id]["error"] = str(exc)
            scrape_jobs[job_id]["finished_at"] = _utc_now()
            latest_job_id = job_id


@router.post("/scrape/play-store")
async def start_scrape(body: ScrapeRequest, background_tasks: BackgroundTasks) -> dict[str, str]:
    job_id = str(uuid4())
    with jobs_lock:
        scrape_jobs[job_id] = {
            "job_id": job_id,
            "status": "pending",
            "created_at": _utc_now(),
            "request": body.model_dump(),
            "result": None,
            "error": None,
        }

    background_tasks.add_task(_run_scrape_job, job_id, body)
    return {"job_id": job_id, "status": "started"}


@router.get("/scrape/status")
async def get_scrape_status(job_id: str | None = Query(default=None)) -> dict[str, Any]:
    lookup_job_id = job_id or latest_job_id
    if not lookup_job_id:
        return {"status": "idle", "job_id": None}

    with jobs_lock:
        job = scrape_jobs.get(lookup_job_id)

    if not job:
        raise HTTPException(status_code=404, detail="Scrape job not found")
    return job
