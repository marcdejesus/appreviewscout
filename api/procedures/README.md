# Procedures: Google Play review scraping for market research

This folder contains scripts and storage used to scrape **Google Play** reviews for motivational apps, store them in SQLite, and flag reviews that contain **feature requests** so you can spot market gaps.

## Setup

From the project root (parent of `procedures/` and `Scrapling/`):

```bash
python3 -m venv .venv
.venv/bin/pip install -e "./Scrapling[fetchers]"
```

## Run the scraper

```bash
# From project root — full scrape: opens app page, clicks "See all reviews", scrolls the modal.
# Requires headless Chromium (playwright install). On Ubuntu, if Chrome fails to start, install:
#   sudo apt-get install libnss3 libnspr4 libatk1.0-0 libx11-6
.venv/bin/python procedures/scrape_google_play_reviews.py --max-scrolls 150

# Scrape until at least 1000 *parsed* reviews (uses calibration ratio to set min_reviews in DOM; run --calibrate once for best accuracy)
.venv/bin/python procedures/scrape_google_play_reviews.py --target-parsed 1000 --save-html data/play_store_reviews_page.html

# Optional: calibrate first (3 test scrapes → saves data/play_store_calibration.json with parsed/dom ratio)
.venv/bin/python procedures/scrape_google_play_reviews.py --calibrate

# Raw DOM target (legacy): stop when this many review nodes in DOM (parsed count will be lower)
.venv/bin/python procedures/scrape_google_play_reviews.py --min-reviews 1000 --save-html data/play_store_reviews_page.html

.venv/bin/python procedures/scrape_google_play_reviews.py --max-scrolls 60 --save-html data/play_store_reviews.html

# If the browser cannot start (e.g. missing libnspr4): use Scrapling Fetcher only (no modal; ~3 reviews on initial page).
.venv/bin/python procedures/scrape_google_play_reviews.py --no-browser

# Scrape reviews for any Play app by URL (app can be pre-added with add_play_app.py, or name is fetched once)
.venv/bin/python procedures/scrape_google_play_reviews.py --url "https://play.google.com/store/apps/details?id=com.mindset.app&hl=en_US" --target-parsed 500
```

### Calibration and target parsed count

Only a fraction of "review nodes" in the DOM become parsed reviews (duplicates, different structure). The scraper uses a **parsed/dom ratio** (default ~0.31) to decide how many DOM nodes to target for a desired parsed count.

- **`--calibrate`** — Runs 3 test scrapes (60, 120, 200 scrolls), records `reviews_in_dom` and `reviews_parsed`, computes the ratio, and saves it to `data/play_store_calibration.json`. Run once per app or when the store layout changes.
- **`--target-parsed N`** — Sets `min_reviews` (DOM target) to `ceil(N / ratio * 1.2)` so you typically get at least N parsed reviews. Uses the saved ratio if present, else 0.31.

## Add a Google Play app by URL

You can add any Google Play app (metadata + icon) so you can scrape its reviews and use it for competitive analysis.

```bash
# Add app by Play Store URL (fetches metadata and icon via Scrapling, upserts into apps table)
.venv/bin/python procedures/add_play_app.py "https://play.google.com/store/apps/details?id=com.mindset.app&hl=en_US"

# Optional: download up to 5 screenshots to data/app_screenshots/{package_id}/
.venv/bin/python procedures/add_play_app.py "https://play.google.com/store/apps/details?id=com.mindset.app&hl=en_US" --download-screenshots

# Custom DB path
.venv/bin/python procedures/add_play_app.py "https://play.google.com/..." --db path/to/reviews.db

# If the details page returns minimal HTML, use stealthy fetch
.venv/bin/python procedures/add_play_app.py "https://play.google.com/..." --stealthy
```

After adding an app, scrape its reviews with `--url` (see above).

## What gets stored

- **SQLite DB** at `data/app_store_reviews.db`:
  - **apps:** `app_id` (Play package id), `app_name`, `play_store_id`, `play_store_url`, **`icon_path`** (e.g. `app_icons/com.example.app.png`), **`download_count`**, **`total_reviews`**, **`description`**, **`screenshots`** (JSON: URLs and/or relative paths) for competitive analysis
  - **reviews:** `rating`, `title`, `content`, `author`, `review_date`, **`platform`** (`Google Play`), **`has_feature_request`** (0/1)

Feature requests are detected by keyword/phrase rules in `feature_request_detector.py` (e.g. "add a setting", "would be nice to", "wish there was").

## Query feature requests

```python
from procedures.reviews_db import get_connection, get_feature_request_reviews

conn = get_connection()
# All feature-request reviews for an app (by play_store_id / app_id)
rows = get_feature_request_reviews(conn, app_store_id="com.hrd.motivation")
# Only Google Play (all reviews are Google Play now)
rows_play = get_feature_request_reviews(conn, app_store_id="com.hrd.motivation", platform="Google Play")
for r in rows:
    print(r["platform"], r.get("title") or r["author"], r["content"][:200])
conn.close()
```

## Files

| File | Purpose |
|------|---------|
| `add_play_app.py` | Add any Google Play app by URL: fetch metadata + icon (and optional screenshots) via Scrapling, upsert into `apps` |
| `play_app_metadata.py` | Parse Play URL (`parse_play_store_url`), fetch and parse app details (`fetch_play_app_details`) using Scrapling only |
| `scrape_google_play_reviews.py` | Google Play: open app page, click "See all reviews", scroll modal, parse, store with `platform='Google Play'`. Supports `--url` for any Play app |
| `reviews_db.py` | SQLite schema, `ensure_app_for_play` / `update_app_metadata`, `insert_review(..., platform='Google Play')`, `get_feature_request_reviews(...)` |
| `feature_request_detector.py` | `has_feature_request(text)` using regex/phrase rules |
| `play_store_calibration.py` | Calibration for target parsed count (`--calibrate`, `--target-parsed`) |

## Default app

- **Google Play:** Motivation - Daily quotes — `https://play.google.com/store/apps/details?id=com.hrd.motivation&hl=en_US`

To add more apps, use `add_play_app.py <play_url>` and then `scrape_google_play_reviews.py --url <play_url>`.
