from __future__ import annotations

import multiprocessing

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from api.config import DATA_DIR
from api.routes.apps import router as apps_router
from api.routes.projects import router as projects_router
from api.routes.reviews import router as reviews_router
from api.routes.scrape import router as scrape_router


app = FastAPI(title="App Review Scout API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(apps_router)
app.include_router(projects_router)
app.include_router(reviews_router)
app.include_router(scrape_router)
app.mount("/static", StaticFiles(directory=DATA_DIR), name="static")


if __name__ == "__main__":
    multiprocessing.freeze_support()
    uvicorn.run(app, host="127.0.0.1", port=8000)
