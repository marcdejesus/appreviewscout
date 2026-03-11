"""
Calibration for Google Play review scraper: run test scrapes, compute parsed/dom ratio
and recommend min_reviews + scroll_pause for a target parsed count.
"""

from __future__ import annotations

import json
import math
import time
from pathlib import Path
from typing import Any

_project_root = Path(__file__).resolve().parent.parent
DEFAULT_CALIBRATION_PATH = _project_root / "data" / "play_store_calibration.json"

# Default ratio from observed run: 307 parsed / 1000 dom ≈ 0.31
DEFAULT_PARSED_PER_DOM_RATIO = 0.31


def load_calibration(path: Path = DEFAULT_CALIBRATION_PATH) -> dict[str, Any]:
    """Load calibration data from JSON. Returns dict with runs, ratio, recommended_scroll_pause_ms."""
    if not path.exists():
        return {
            "runs": [],
            "parsed_per_dom_ratio": DEFAULT_PARSED_PER_DOM_RATIO,
            "recommended_scroll_pause_ms": 2000,
        }
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        data.setdefault("runs", [])
        data.setdefault("parsed_per_dom_ratio", DEFAULT_PARSED_PER_DOM_RATIO)
        data.setdefault("recommended_scroll_pause_ms", 2000)
        return data
    except Exception:
        return {
            "runs": [],
            "parsed_per_dom_ratio": DEFAULT_PARSED_PER_DOM_RATIO,
            "recommended_scroll_pause_ms": 2000,
        }


def save_calibration(data: dict[str, Any], path: Path = DEFAULT_CALIBRATION_PATH) -> None:
    """Save calibration data to JSON."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def min_reviews_for_target_parsed(
    target_parsed: int,
    parsed_per_dom_ratio: float | None = None,
    calibration_path: Path = DEFAULT_CALIBRATION_PATH,
) -> int:
    """
    Recommended min_reviews (DOM target) to get at least target_parsed parsed reviews.
    Uses calibration ratio if available, else DEFAULT_PARSED_PER_DOM_RATIO.
    Adds 20% buffer so we usually exceed target.
    """
    cal = load_calibration(calibration_path)
    ratio = parsed_per_dom_ratio or cal.get("parsed_per_dom_ratio") or DEFAULT_PARSED_PER_DOM_RATIO
    if ratio <= 0:
        ratio = DEFAULT_PARSED_PER_DOM_RATIO
    # buffer 20% so we typically get >= target_parsed
    raw = target_parsed / ratio
    return max(1, math.ceil(raw * 1.2))


def run_calibration(
    max_scrolls_list: list[int] | None = None,
    scroll_pause_ms: int = 2000,
    save_path: Path = DEFAULT_CALIBRATION_PATH,
    run_scrape_fn: Any = None,
) -> dict[str, Any]:
    """
    Run a few test scrapes with different max_scrolls, record (scrolls, dom_count, parsed_count),
    compute parsed_per_dom_ratio, and save. run_scrape_fn(reviews_in_dom, max_scrolls, scroll_pause_ms)
    should return dict with reviews_parsed, reviews_in_dom.
    """
    if max_scrolls_list is None:
        max_scrolls_list = [60, 120, 200]
    if run_scrape_fn is None:
        from procedures.scrape_google_play_reviews import run_scrape
        run_scrape_fn = run_scrape

    runs: list[dict[str, Any]] = []
    for max_scrolls in max_scrolls_list:
        start = time.perf_counter()
        result = run_scrape_fn(
            max_scrolls=max_scrolls,
            scroll_pause_ms=scroll_pause_ms,
            min_reviews=0,  # don't stop early; use all scrolls
            save_html_path=None,
        )
        elapsed = time.perf_counter() - start
        dom = result.get("reviews_in_dom") or 0
        parsed = result.get("reviews_parsed") or 0
        runs.append({
            "max_scrolls": max_scrolls,
            "reviews_in_dom": dom,
            "reviews_parsed": parsed,
            "elapsed_sec": round(elapsed, 1),
        })
        ratio = parsed / dom if dom else 0
        runs[-1]["parsed_per_dom_ratio"] = round(ratio, 4)

    # Overall ratio: total_parsed / total_dom across runs (or mean of per-run ratios)
    total_dom = sum(r["reviews_in_dom"] for r in runs)
    total_parsed = sum(r["reviews_parsed"] for r in runs)
    overall_ratio = total_parsed / total_dom if total_dom else DEFAULT_PARSED_PER_DOM_RATIO

    data: dict[str, Any] = {
        "runs": runs,
        "parsed_per_dom_ratio": round(overall_ratio, 4),
        "recommended_scroll_pause_ms": scroll_pause_ms,
        "formula_min_reviews": "ceil(target_parsed / parsed_per_dom_ratio * 1.2)",
    }
    save_calibration(data, save_path)
    return data
