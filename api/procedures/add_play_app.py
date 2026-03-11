"""
Add a Google Play app by URL: fetch metadata and icon (and optionally screenshots) using Scrapling,
then upsert into the apps table. All network fetches use Scrapling Fetcher only.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_project_root = Path(__file__).resolve().parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

from scrapling.fetchers import Fetcher

from procedures.play_app_metadata import (
    fetch_play_app_details,
    parse_play_store_url,
)
from procedures.reviews_db import (
    DEFAULT_DB_PATH,
    get_connection,
    ensure_app_for_play,
    update_app_metadata,
)


DATA_DIR = _project_root / "data"
APP_ICONS_DIR = DATA_DIR / "app_icons"
APP_SCREENSHOTS_DIR = DATA_DIR / "app_screenshots"


def _download_icon(icon_url: str, play_store_id: str) -> str | None:
    """
    Download app icon using Scrapling Fetcher.get; save to data/app_icons/{play_store_id}.png.
    Returns relative path (e.g. app_icons/com.example.app.png) or None on failure.
    """
    if not icon_url:
        return None
    try:
        response = Fetcher.get(icon_url, stealthy_headers=True, timeout=30)
        body = response.body
        if isinstance(body, str):
            body = body.encode("utf-8", errors="replace")
        if not body:
            return None
        APP_ICONS_DIR.mkdir(parents=True, exist_ok=True)
        ext = ".png"
        if ".webp" in icon_url.lower():
            ext = ".webp"
        path = APP_ICONS_DIR / f"{play_store_id}{ext}"
        path.write_bytes(body)
        return f"app_icons/{play_store_id}{ext}"
    except Exception as e:
        print(f"Warning: could not download icon: {e}", file=sys.stderr)
        return None


def _download_screenshots(screenshot_urls: list[str], play_store_id: str, max_n: int = 5) -> list[dict]:
    """
    Download up to max_n screenshots using Scrapling Fetcher.get; save to data/app_screenshots/{play_store_id}/.
    Returns list of dicts with "path" and optionally "url" for the screenshots JSON column.
    """
    out: list[dict] = []
    if not screenshot_urls:
        return out
    dir_path = APP_SCREENSHOTS_DIR / play_store_id
    dir_path.mkdir(parents=True, exist_ok=True)
    for i, url in enumerate(screenshot_urls[:max_n]):
        try:
            response = Fetcher.get(url, stealthy_headers=True, timeout=30)
            body = response.body
            if isinstance(body, str):
                body = body.encode("utf-8", errors="replace")
            if not body:
                continue
            ext = ".png"
            if ".webp" in url.lower():
                ext = ".webp"
            path = dir_path / f"{i + 1}{ext}"
            path.write_bytes(body)
            rel = f"app_screenshots/{play_store_id}/{i + 1}{ext}"
            out.append({"path": rel, "url": url})
        except Exception as e:
            print(f"Warning: could not download screenshot {i + 1}: {e}", file=sys.stderr)
    return out


def add_play_app(
    url: str,
    *,
    db_path: Path | None = None,
    download_screenshots: bool = False,
    use_stealthy: bool = False,
) -> dict:
    """
    Parse URL, fetch metadata (Scrapling), download icon (Scrapling), optionally screenshots,
    then ensure_app_for_play + update_app_metadata. Returns dict with app_name, play_store_id, icon_path, etc.
    """
    play_store_id = parse_play_store_url(url)
    if not play_store_id:
        raise ValueError(f"Invalid Play Store app URL (missing id): {url}")

    details = fetch_play_app_details(url, use_stealthy=use_stealthy)
    app_name = details.get("app_name") or play_store_id

    icon_path_rel: str | None = None
    if details.get("icon_url"):
        icon_path_rel = _download_icon(details["icon_url"], play_store_id)

    screenshots_json: list = []
    if download_screenshots and details.get("screenshot_urls"):
        screenshots_json = _download_screenshots(details["screenshot_urls"], play_store_id)
    else:
        screenshots_json = [{"url": u} for u in (details.get("screenshot_urls") or [])[:20]]

    conn = get_connection(db_path)
    ensure_app_for_play(
        conn,
        play_store_id,
        app_name,
        play_store_url=url,
    )
    update_app_metadata(
        conn,
        play_store_id,
        icon_path=icon_path_rel,
        download_count=details.get("download_count") or None,
        total_reviews=details.get("total_reviews") or None,
        description=details.get("description") or None,
        screenshots=screenshots_json if screenshots_json else None,
    )
    conn.close()

    return {
        "app_name": app_name,
        "play_store_id": play_store_id,
        "icon_path": icon_path_rel,
        "download_count": details.get("download_count"),
        "total_reviews": details.get("total_reviews"),
        "screenshots_count": len(screenshots_json),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add a Google Play app by URL; fetch metadata and icon (Scrapling only), save to DB.",
    )
    parser.add_argument(
        "url",
        nargs="?",
        default="",
        help="Play Store app details URL (e.g. https://play.google.com/store/apps/details?id=com.example.app&hl=en_US)",
    )
    parser.add_argument("--db", type=Path, default=None, help="Path to SQLite DB (default: data/app_store_reviews.db)")
    parser.add_argument("--download-screenshots", action="store_true", help="Download up to 5 screenshots to data/app_screenshots/")
    parser.add_argument("--stealthy", action="store_true", help="Use StealthyFetcher for details page (if Fetcher.get returns minimal HTML)")
    args = parser.parse_args()

    url = (args.url or "").strip()
    if not url:
        parser.print_help()
        sys.exit(1)

    try:
        result = add_play_app(
            url,
            db_path=args.db or DEFAULT_DB_PATH,
            download_screenshots=args.download_screenshots,
            use_stealthy=args.stealthy,
        )
        print(f"Added app: {result['app_name']} ({result['play_store_id']})")
        if result.get("icon_path"):
            print(f"  Icon saved: {result['icon_path']}")
        if result.get("download_count"):
            print(f"  Downloads: {result['download_count']}")
        if result.get("total_reviews"):
            print(f"  Reviews: {result['total_reviews']}")
        if result.get("screenshots_count"):
            print(f"  Screenshots: {result['screenshots_count']} (URLs or files)")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
