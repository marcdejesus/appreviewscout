# AppReviewScout

A local desktop app for viewing scraped app reviews, managing projects, and identifying feature requests — no Python or terminal required for end users.

**Target platforms:** Windows, macOS, Linux.

## Stack

- **Frontend:** Flutter (desktop)
- **Backend:** FastAPI + uvicorn (Python), SQLite

The Flutter app talks to the API over `localhost`. On launch it starts the bundled API server and polls `/health` until ready.

## Project structure

```
api/                 # FastAPI app (apps, reviews, projects, scrape routes)
api/procedures/          # DB and scraping logic
appreviewscout/       # Flutter desktop app
data/                # SQLite database (local)
tests/               # API tests (pytest)
```

## Getting started

### API

```bash
python -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
uvicorn api.main:app --reload
```

API runs at `http://127.0.0.1:8000`. Docs: `http://127.0.0.1:8000/docs`.

### Flutter app

```bash
cd appreviewscout
flutter pub get
flutter run -d linux   # or windows, macos
```

Point the app at the same machine (default: `127.0.0.1:8000`).

## Features

- **Projects** — Group apps into projects; filter apps, reviews, and pinned items by active project (or “All”).
- **Apps** — List and add Play Store apps (with optional screenshot download).
- **Reviews** — Browse and filter reviews; mark and view feature requests.
- **Pinned** — Pinned reviews for quick access.
- **Scrape** — Trigger Play Store review scraping from the UI.

## Tests

```bash
.venv/bin/python -m pytest tests/ -v
```

## License

Private / unlicensed unless stated otherwise.
