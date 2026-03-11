"""
Scrape Google Play Store reviews using Scrapling (scrapling-official skill).

- Fetch: StealthyFetcher for browser automation (click "See all reviews", scroll modal).
- Parse: Selector with .css() for review blocks, rating, author, date, content.
- Optional: Fetcher.get() for initial page when testing without modal; or --html to parse from file.

Follows scrapling-official: use stealthy-fetch for dynamic content; parse with Selector.
"""

from __future__ import annotations

import sys
import re
import logging
from pathlib import Path
from typing import Any

_project_root = Path(__file__).resolve().parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

from scrapling.fetchers import Fetcher, StealthyFetcher
from scrapling.parser import Selector

from procedures.reviews_db import (
    cleanup_show_review_history_reviews,
    get_connection,
    ensure_app_for_play,
    get_feature_request_reviews,
    insert_review,
)
from procedures.feature_request_detector import has_feature_request
from procedures.play_app_metadata import parse_play_store_url, fetch_play_app_details

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# Default app: Motivation - Daily quotes on Google Play
PLAY_STORE_ID = "com.hrd.motivation"
PLAY_APP_NAME = "Motivation - Daily quotes"
PLAY_APP_URL = "https://play.google.com/store/apps/details?id=com.hrd.motivation&hl=en_US"


def _make_play_store_page_action(
    max_scrolls: int = 50,
    scroll_pause_ms: int = 1500,
    min_reviews: int = 0,
    capture_html: list[str] | None = None,
    capture_dom_count: list[int] | None = None,
) -> Any:
    """
    Return a page_action that: waits for page, scrolls to reviews section, clicks "See all reviews",
    then scrolls the modal until we have min_reviews (or max_scrolls / no new content).
    If capture_html is provided (a list), append the full DOM HTML at the end.
    If capture_dom_count is provided, append the final review-node count (for calibration).
    """
    def page_action(page: Any) -> None:
        # Wait for app page and reviews section to be present
        try:
            page.wait_for_selector("[data-review-id], .RHo1pe, .VfPpkd-vQzf8d", timeout=20000)
        except Exception:
            pass
        page.wait_for_timeout(2000)
        # Scroll main page down so "Ratings and reviews" / "See all" is in view
        for _ in range(5):
            page.evaluate("window.scrollBy(0, 400)")
            page.wait_for_timeout(400)
        page.wait_for_timeout(1000)

        # Click "See all reviews" (Play Store: "See more information on Ratings and reviews" or "See all review")
        clicked = False
        for attempt_name, locator in [
            ("button Ratings and reviews", page.get_by_role("button", name=re.compile(r"See more information on Ratings and reviews|Ratings and reviews", re.I))),
            ("link Ratings and reviews", page.get_by_role("link", name=re.compile(r"See more information on Ratings and reviews|See all review", re.I))),
            ("link See all review", page.get_by_role("link", name=re.compile(r"See all review", re.I))),
            ("button See all", page.get_by_role("button", name=re.compile(r"See all review", re.I))),
            ("text See all", page.get_by_text("See all", exact=False)),
            (".VfPpkd-vQzf8d", page.locator(".VfPpkd-vQzf8d").filter(has_text=re.compile(r"See all|Rating", re.I))),
        ]:
            try:
                locator.first.click(timeout=8000)
                clicked = True
                logger.info("Opened reviews panel with: %s", attempt_name)
                break
            except Exception as e:
                logger.debug("Click attempt %s failed: %s", attempt_name, e)
        if not clicked:
            logger.warning("Could not click 'See all reviews'; will scroll main page only (fewer reviews).")

        page.wait_for_timeout(2000)

        # If we only expanded the section, click "See all review" link to open the full modal
        try:
            page.evaluate("window.scrollBy(0, 300)")
            page.wait_for_timeout(500)
            see_all = page.get_by_role("link", name=re.compile(r"See all review", re.I)).first
            see_all.scroll_into_view_if_needed(timeout=3000)
            page.wait_for_timeout(300)
            see_all.click(timeout=5000)
            logger.info("Clicked 'See all review' to open full reviews modal")
            page.wait_for_timeout(3000)
        except Exception as e:
            logger.debug("Second click 'See all review' skipped: %s", e)

        # Find and scroll the *inner* scrollable element (dialog itself often isn't scrollable; child is)
        # Play Store: .odk6He or any div inside dialog with scrollHeight > clientHeight
        scroll_js = """
        () => {
            const findScrollable = (root, deep) => {
                const sel = 'div[style*="overflow"], .odk6He, .fysCi, [class*="scroll"]';
                let best = null, maxScroll = 0;
                for (const el of root.querySelectorAll(sel)) {
                    const sh = el.scrollHeight, ch = el.clientHeight;
                    if (sh > ch && sh > maxScroll) { maxScroll = sh; best = el; }
                }
                if (best) return best;
                if (deep) {
                    const divs = root.querySelectorAll('div');
                    for (const el of divs) {
                        if (el.scrollHeight > el.clientHeight && el.scrollHeight > maxScroll) {
                            maxScroll = el.scrollHeight; best = el;
                        }
                    }
                }
                return best;
            };
            const dialog = document.querySelector('[role="dialog"]');
            const el = dialog ? (findScrollable(dialog, true) || dialog) : null;
            if (el) {
                el.scrollTop = el.scrollHeight;
                return true;
            }
            window.scrollBy(0, 800);
            return true;
        }
        """
        last_count = 0
        stable = 0
        pause = scroll_pause_ms
        if min_reviews:
            pause = max(pause, 2000)
        for i in range(max_scrolls):
            try:
                page.evaluate(scroll_js)
            except Exception:
                page.evaluate("window.scrollBy(0, 800)")
            page.wait_for_timeout(pause)
            try:
                count = page.locator("[data-review-id], .RHo1pe, .jftApd, div.h3YV2d").count()
                if count > last_count:
                    last_count = count
                    stable = 0
                    if (i + 1) % 5 == 0 or i < 3:
                        logger.info("Reviews in DOM: %d", count)
                else:
                    stable += 1
                    if stable >= 4:
                        logger.info("No new reviews for 4 scrolls; stopping at %d", count)
                        break
                if min_reviews and count >= min_reviews:
                    logger.info("Reached target of %d reviews", min_reviews)
                    break
            except Exception:
                pass
        page.wait_for_timeout(500)

        if capture_dom_count is not None:
            capture_dom_count.clear()
            capture_dom_count.append(last_count)

        # Capture full DOM so we parse what we scrolled (response.body may be initial HTML only)
        if capture_html is not None:
            try:
                full_html = page.content()
                if full_html:
                    capture_html.clear()
                    capture_html.append(full_html)
                    logger.info("Captured full DOM for parsing (%s chars)", len(full_html))
            except Exception as e:
                logger.warning("Could not capture page.content(): %s", e)

    return page_action


def _get_play_store_html_no_browser(url: str = PLAY_APP_URL) -> str:
    """Fetch Play Store app page with Scrapling Fetcher (no browser). Only gets initial HTML; no 'See all reviews' modal."""
    response = Fetcher.get(url, stealthy_headers=True, timeout=30)
    return response.body.decode("utf-8", errors="replace")


def _get_play_store_html(
    url: str = PLAY_APP_URL,
    max_scrolls: int = 50,
    scroll_pause_ms: int = 1500,
    min_reviews: int = 0,
    *,
    no_browser: bool = False,
    capture_html: list[str] | None = None,
    capture_dom_count: list[int] | None = None,
) -> str:
    """Fetch Play Store app page with Scrapling. If no_browser, use Fetcher.get(); else StealthyFetcher + modal scroll. Uses captured DOM when capture_html is provided."""
    if no_browser:
        return _get_play_store_html_no_browser(url)
    if capture_html is None:
        capture_html = []
    if capture_dom_count is None:
        capture_dom_count = []
    response = StealthyFetcher.fetch(
        url,
        headless=True,
        wait=3000,
        timeout=180000,
        page_action=_make_play_store_page_action(
            max_scrolls,
            scroll_pause_ms,
            min_reviews,
            capture_html=capture_html,
            capture_dom_count=capture_dom_count,
        ),
    )
    if capture_html:
        return capture_html[0]
    return response.body.decode("utf-8", errors="replace")


def _parse_play_store_reviews(html: str, url: str = PLAY_APP_URL) -> list[dict[str, Any]]:
    """Parse review blocks from Google Play HTML using Scrapling Selector (.css())."""
    sel = Selector(content=html, url=url)
    reviews: list[dict[str, Any]] = []
    seen: set[tuple[str, int]] = set()
    seen_ids: set[str] = set()

    def add_review(r: dict[str, Any] | None) -> bool:
        if not r or not r.get("content") or len(r["content"]) < 20:
            return False
        key = (r["content"][:80].strip(), r.get("rating") or 0)
        if key in seen:
            return False
        seen.add(key)
        reviews.append(r)
        return True

    # 1) div.h3YV2d (review body); use parent for author/date/rating
    blocks = list(sel.css("div.h3YV2d"))
    if blocks:
        for b in blocks:
            parent = b.parent if b.parent is not None else b
            add_review(_extract_play_review(parent))

    # 2) [data-review-id] (captures more in dynamic DOM; dedupe by id)
    for block in sel.css("[data-review-id]"):
        attrib = getattr(block, "attrib", None) or {}
        rid = attrib.get("data-review-id", "")
        if rid and rid in seen_ids:
            continue
        if rid:
            seen_ids.add(rid)
        add_review(_extract_play_review(block))

    if not reviews:
        fallback = list(sel.css(".RHo1pe, .jftApd, div[jscontroller]")) or list(sel.css("div[jscontroller]"))
        for block in fallback:
            add_review(_extract_play_review(block))
    return reviews


def _extract_play_review(block: Any) -> dict[str, Any] | None:
    """Extract rating, author, date, content from a Play Store review block."""
    rating = None
    author = ""
    review_date = ""
    content = ""

    # Star rating: aria-label="5 stars" or "3 out of 5 stars"
    try:
        for el in block.css("[aria-label*='star'], [role='img'][aria-label]"):
            attrib = getattr(el, "attrib", None)
            if not attrib:
                continue
            label = (attrib.get("aria-label") or "").lower()
            m = re.search(r"(\d)\s*(?:out of 5)?\s*stars?", label)
            if m:
                rating = int(m.group(1))
                break
    except Exception:
        pass

    # Reviewer name: common classes
    for sel in [".X43Kjb", "[class*='author']", "span[itemprop='author']"]:
        try:
            nodes = list(block.css(sel))
            if nodes:
                author = (nodes[0].get_all_text() or "").strip()
                if author and len(author) < 100:
                    break
        except Exception:
            pass

    # Date
    for sel in ["span[class*='date'], .bp9Aid", "span[itemprop='datePublished']"]:
        try:
            nodes = list(block.css(sel))
            if nodes:
                review_date = (nodes[0].get_all_text() or "").strip()
                break
        except Exception:
            pass

    # Review body: div.h3YV2d (Play Store 2024+), then span[jsname='bN97Pc'] / .UD7Dzf
    for sel in ["div.h3YV2d", "span[jsname='bN97Pc']", "span[jsname='fbQN7e']", ".UD7Dzf", ".review-body-with-text"]:
        try:
            nodes = list(block.css(sel))
            for n in nodes:
                t = (n.get_all_text() or "").strip()
                if "people found this review helpful" in t or "Did you find this helpful" in t:
                    t = t.split("people found")[0].split("Did you find")[0].strip()
                if "Flag inappropriate" in t or "more_vert" in t:
                    continue
                if len(t) > 40 and t != author and not t.startswith("December") and not t.startswith("February") and not t.startswith("January"):
                    content = t
                    break
            if content:
                break
        except Exception:
            pass
    if not content and hasattr(block, "get_all_text"):
        content = (block.get_all_text() or "").strip()
        for sep in ["people found this review helpful", "Did you find this helpful"]:
            if sep in content:
                content = content.split(sep)[0].strip()
        if "Flag inappropriate" in content:
            content = content.split("Flag inappropriate")[-1].strip()

    if not content:
        return None
    return {
        "rating": rating,
        "title": "",
        "content": content,
        "author": author or "A Google user",
        "review_date": review_date,
    }


def run_scrape(
    url: str = PLAY_APP_URL,
    play_store_id: str = PLAY_STORE_ID,
    app_name: str = PLAY_APP_NAME,
    max_scrolls: int = 50,
    scroll_pause_ms: int = 1500,
    min_reviews: int = 0,
    db_path: Path | None = None,
    save_html_path: Path | None = None,
    html_file: Path | None = None,
    no_browser: bool = False,
) -> dict[str, Any]:
    """Fetch Play Store reviews (modal + scroll), parse, store with platform='Google Play'. If html_file is set, skip fetch and parse that file (for testing). no_browser uses Fetcher.get() (fewer reviews, no modal)."""
    if html_file and html_file.exists():
        logger.info("Using HTML from file: %s", html_file)
        html = html_file.read_text(encoding="utf-8", errors="replace")
    else:
        if no_browser:
            logger.info("Fetching Google Play page with Scrapling Fetcher (no browser): %s", url)
        else:
            logger.info(
                "Fetching Google Play reviews: %s (max_scrolls=%s, min_reviews=%s)",
                url, max_scrolls, min_reviews or "none",
            )
        capture_html_list: list[str] = []
        capture_dom_count_list: list[int] = []
        try:
            html = _get_play_store_html(
                url,
                max_scrolls=max_scrolls,
                scroll_pause_ms=scroll_pause_ms,
                min_reviews=min_reviews,
                no_browser=no_browser,
                capture_html=capture_html_list,
                capture_dom_count=capture_dom_count_list,
            )
        except Exception as e:
            err_msg = str(e).lower()
            if "target closed" in err_msg or "libnspr4" in err_msg or "browser" in err_msg or "launch" in err_msg:
                logger.error("Chromium could not start (often due to missing system libraries like libnspr4).")
                logger.error("On Ubuntu/Debian/WSL, install dependencies with:")
                logger.error("  sudo apt-get update && sudo apt-get install -y libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 libpango-1.0-0 libcairo2")
                logger.error("Then run this script again. Alternatively, use --no-browser for a limited fetch without a browser.")
            raise

    if save_html_path:
        save_html_path.parent.mkdir(parents=True, exist_ok=True)
        save_html_path.write_text(html, encoding="utf-8")
        logger.info("Saved HTML to %s (%s bytes)", save_html_path, len(html))

    reviews = _parse_play_store_reviews(html, url=url)
    logger.info("Parsed %d reviews from Play Store HTML", len(reviews))

    conn = get_connection(db_path)
    app_pk = ensure_app_for_play(
        conn,
        play_store_id=play_store_id,
        app_name=app_name,
        play_store_url=url,
    )
    inserted = 0
    feature_request_count = 0

    for r in reviews:
        is_fr = has_feature_request(r.get("title", "") + " " + r.get("content", ""))
        if is_fr:
            feature_request_count += 1
        if insert_review(
            conn,
            app_pk=app_pk,
            rating=r.get("rating"),
            title=r.get("title", ""),
            content=r.get("content", ""),
            author=r.get("author", ""),
            review_date=r.get("review_date", ""),
            has_feature_request=is_fr,
            platform="Google Play",
        ):
            inserted += 1

    cleanup_result = cleanup_show_review_history_reviews(conn, app_pk=app_pk)
    if cleanup_result["deleted"] or cleanup_result["updated"]:
        logger.info(
            "Cleanup: removed %d empty 'Show review history' reviews, fixed %d with trailing content",
            cleanup_result["deleted"],
            cleanup_result["updated"],
        )
    conn.close()
    logger.info("Inserted %d new reviews (Google Play); %d flagged as feature requests", inserted, feature_request_count)

    conn2 = get_connection(db_path)
    fr_list = get_feature_request_reviews(conn2, app_store_id=play_store_id)
    conn2.close()

    reviews_in_dom = capture_dom_count_list[0] if capture_dom_count_list else None
    return {
        "reviews_parsed": len(reviews),
        "reviews_inserted": inserted,
        "reviews_in_dom": reviews_in_dom,
        "feature_requests_flagged": feature_request_count,
        "feature_request_reviews": fr_list,
    }


def _resolve_url_play_store_id_app_name(
    url: str | None,
    db_path: Path | None,
) -> tuple[str, str, str]:
    """
    When url is provided, return (url, play_store_id, app_name).
    Otherwise (url None), return default PLAY_APP_URL, PLAY_STORE_ID, PLAY_APP_NAME.
    """
    if not url or not url.strip():
        return PLAY_APP_URL, PLAY_STORE_ID, PLAY_APP_NAME
    url = url.strip()
    play_store_id = parse_play_store_url(url)
    if not play_store_id:
        raise ValueError(f"Invalid Play Store app URL (missing id): {url}")
    conn = get_connection(db_path)
    try:
        cur = conn.execute("SELECT app_name FROM apps WHERE play_store_id = ?", (play_store_id,))
        row = cur.fetchone()
        if row:
            return url, play_store_id, row["app_name"]
    finally:
        conn.close()
    details = fetch_play_app_details(url, use_stealthy=False)
    app_name = details.get("app_name") or play_store_id
    return url, play_store_id, app_name


def main() -> None:
    import argparse
    p = argparse.ArgumentParser(description="Scrape Google Play reviews (modal + infinite scroll)")
    p.add_argument("--url", "--play-url", dest="url", type=str, default=None, help="Play Store app details URL (e.g. https://play.google.com/store/apps/details?id=com.example.app). If omitted, uses default Motivation app.")
    p.add_argument("--max-scrolls", type=int, default=50, help="Max scroll rounds in reviews modal")
    p.add_argument("--scroll-pause", type=int, default=1500, help="Pause ms between scrolls")
    p.add_argument("--min-reviews", type=int, default=0, help="Keep scrolling until at least this many reviews in DOM (e.g. 1000)")
    p.add_argument("--target-parsed", type=int, default=0, help="Target number of parsed reviews; sets min_reviews from calibration ratio (run --calibrate first for accuracy)")
    p.add_argument("--calibrate", action="store_true", help="Run calibration (3 test scrapes), save formula to data/play_store_calibration.json")
    p.add_argument("--save-html", type=Path, default=None, help="Save fetched HTML here")
    p.add_argument("--html", type=Path, default=None, help="Parse from this HTML file instead of fetching (test/dry-run)")
    p.add_argument("--db", type=Path, default=None, help="SQLite database path")
    p.add_argument("--no-browser", action="store_true", help="Use Fetcher.get() instead of StealthyFetcher (no modal; only reviews in initial HTML)")
    args = p.parse_args()

    if args.calibrate:
        from procedures.play_store_calibration import run_calibration, DEFAULT_CALIBRATION_PATH
        print("Running calibration (3 test scrapes: 60, 120, 200 scrolls)...")
        data = run_calibration(
            max_scrolls_list=[60, 120, 200],
            scroll_pause_ms=max(args.scroll_pause, 2000),
            save_path=DEFAULT_CALIBRATION_PATH,
        )
        print("\n--- Calibration results ---")
        for r in data["runs"]:
            print(f"  max_scrolls={r['max_scrolls']}: dom={r['reviews_in_dom']}, parsed={r['reviews_parsed']}, ratio={r.get('parsed_per_dom_ratio', 0):.3f}")
        print(f"  parsed_per_dom_ratio: {data['parsed_per_dom_ratio']}")
        print(f"  Saved to {DEFAULT_CALIBRATION_PATH}")
        print("  Use --target-parsed 1000 to aim for ~1000 parsed reviews (min_reviews will be set automatically).")
        return

    url, play_store_id, app_name = _resolve_url_play_store_id_app_name(
        args.url, args.db,
    )
    save_path = args.save_html or (_project_root / "data" / "play_store_reviews_page.html")
    max_scrolls = args.max_scrolls
    min_reviews = args.min_reviews
    if args.target_parsed:
        from procedures.play_store_calibration import min_reviews_for_target_parsed
        min_reviews = min_reviews_for_target_parsed(args.target_parsed)
        logger.info("Target %d parsed reviews -> min_reviews (DOM) = %d", args.target_parsed, min_reviews)
    if min_reviews and max_scrolls < 200:
        max_scrolls = max(max_scrolls, 400)
    result = run_scrape(
        url=url,
        play_store_id=play_store_id,
        app_name=app_name,
        max_scrolls=max_scrolls,
        scroll_pause_ms=args.scroll_pause,
        min_reviews=min_reviews,
        db_path=args.db,
        save_html_path=save_path,
        html_file=args.html,
        no_browser=args.no_browser,
    )

    print("\n--- Results (Google Play) ---")
    if result.get("reviews_in_dom") is not None:
        print("Reviews in DOM (at stop):", result["reviews_in_dom"])
    print("Reviews parsed:", result["reviews_parsed"])
    print("New reviews inserted:", result["reviews_inserted"])
    print("Feature requests flagged:", result["feature_requests_flagged"])
    if result["feature_request_reviews"]:
        print("\n--- Feature request reviews ---")
        for r in result["feature_request_reviews"][:15]:
            if r.get("platform") == "Google Play":
                print("-", r.get("author"), "|", (r.get("content") or "")[:100] + "...")


if __name__ == "__main__":
    main()
