"""
Parse Google Play app details URL and fetch/parse app metadata using Scrapling only.

- URL parsing: urllib.parse (not network fetch).
- Page fetch: Fetcher.get() or StealthyFetcher.fetch() from scrapling.fetchers.
- HTML parse: Selector from scrapling.parser (.css(), .xpath(), .find_all()).
- No requests, urllib.request for HTTP, or BeautifulSoup.
"""

from __future__ import annotations

import re
from urllib.parse import parse_qs, urlparse

from scrapling.fetchers import Fetcher, StealthyFetcher
from scrapling.parser import Selector


def parse_play_store_url(url: str) -> str | None:
    """
    Parse a Google Play app details URL and return the package id (e.g. com.hrd.motivation).
    Returns None if the URL is not a valid Play Store app details URL or id is missing.
    """
    try:
        parsed = urlparse(url)
        if "/store/apps/details" not in parsed.path:
            return None
        qs = parse_qs(parsed.query)
        ids = qs.get("id")
        if not ids or not ids[0].strip():
            return None
        return ids[0].strip()
    except Exception:
        return None


def _get_html(url: str, use_stealthy: bool = False) -> str:
    """Fetch Play Store app details page; use StealthyFetcher if use_stealthy (for JS-rendered content)."""
    if use_stealthy:
        response = StealthyFetcher.fetch(url, headless=True, wait=3000, timeout=30000)
        return response.body.decode("utf-8", errors="replace")
    response = Fetcher.get(url, stealthy_headers=True, timeout=30)
    return response.body.decode("utf-8", errors="replace")


def _extract_from_script(html: str) -> dict:
    """Extract app name, icon, description, etc. from meta tags and embedded URLs (no full JSON parse)."""
    out: dict = {"screenshot_urls": []}
    # og:image (icon) and og:title (app name) in meta
    for meta in re.finditer(
        r'<meta[^>]+(?:property|name)=["\'](og:image|og:title)["\'][^>]+content=["\']([^"\']+)["\']',
        html,
    ):
        kind, content = meta.group(1), meta.group(2)
        if kind == "og:image" and "googleusercontent" in content:
            out.setdefault("icon_url", content)
        elif kind == "og:title":
            out.setdefault("app_name", content.strip())
    # Also content before property
    for meta in re.finditer(
        r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\'](og:image|og:title)["\']',
        html,
    ):
        content, kind = meta.group(1), meta.group(2)
        if kind == "og:image" and "googleusercontent" in content:
            out.setdefault("icon_url", content)
        elif kind == "og:title":
            out.setdefault("app_name", content.strip())
    # High-res icon: play-lh.googleusercontent.com ... =s512 or =s256
    if not out.get("icon_url"):
        for m in re.finditer(
            r'https://play-lh\.googleusercontent\.com/[^\s"\'<>]+',
            html,
        ):
            url = m.group(0).rstrip("\\")
            if "=s" in url or "=w" in url:
                out.setdefault("icon_url", url)
                break
    # Screenshot-like URLs (often contain =s0 or =w720 etc.)
    for m in re.finditer(
        r'https://play-lh\.googleusercontent\.com/[^\s"\'<>]+',
        html,
    ):
        url = m.group(0).rstrip("\\")
        if url != out.get("icon_url") and url not in out["screenshot_urls"]:
            out["screenshot_urls"].append(url)
    out["screenshot_urls"] = out["screenshot_urls"][:20]
    return out


def fetch_play_app_details(url: str, use_stealthy: bool = False) -> dict:
    """
    Fetch Google Play app details page with Scrapling and parse metadata.
    Returns dict with: app_name, icon_url, download_count, total_reviews, description, screenshot_urls.
    Uses only Scrapling (Fetcher/StealthyFetcher + Selector). No requests/BeautifulSoup.
    """
    html = _get_html(url, use_stealthy=use_stealthy)
    sel = Selector(content=html, url=url)

    result: dict = {
        "app_name": "",
        "icon_url": "",
        "download_count": "",
        "total_reviews": "",
        "description": "",
        "screenshot_urls": [],
    }

    # App name: h1, or [itemprop="name"], or meta og:title
    for selector in ["h1", "[itemprop='name']", "h1.Fd93Bb"]:
        nodes = list(sel.css(selector))
        if nodes:
            t = (nodes[0].get_all_text() or "").strip()
            if t and len(t) < 200:
                result["app_name"] = t
                break
    if not result["app_name"]:
        from_script = _extract_from_script(html)
        result["app_name"] = from_script.get("app_name") or ""

    # Icon: img[itemprop="image"], or og:image from script/meta
    for node in sel.css("img[itemprop='image'], img.T75of.sM2Zrb"):
        attrib = getattr(node, "attrib", None) or {}
        src = attrib.get("src") or attrib.get("data-src")
        if src and "googleusercontent" in src:
            result["icon_url"] = src
            break
    if not result["icon_url"]:
        for node in sel.css("link[rel='image_src'], meta[property='og:image']"):
            attrib = getattr(node, "attrib", None) or {}
            href = attrib.get("href") or attrib.get("content")
            if href and "googleusercontent" in href:
                result["icon_url"] = href
                break
    if not result["icon_url"]:
        from_script = _extract_from_script(html)
        result["icon_url"] = from_script.get("icon_url") or ""

    # Download count / total reviews: text like "1M+ downloads", "6.17K reviews"
    for node in sel.css("div.bARER, div.ClM7O, span.htlgb, div.IQ1z0"):
        t = (node.get_all_text() or "").strip()
        if re.search(r"[\d.]+\s*[KMB]?\+\s*downloads?", t, re.I):
            result["download_count"] = t.split("downloads")[0].strip() if "download" in t.lower() else t
        if re.search(r"[\d.]+\s*[KMB]?\s*reviews?", t, re.I):
            result["total_reviews"] = t.split("reviews")[0].strip() if "review" in t.lower() else t
    if not result["download_count"]:
        dm = re.search(r"([\d.]+\s*[KMB]?\+?)\s*downloads?", html, re.I)
        if dm:
            result["download_count"] = dm.group(1).strip()
    if not result["total_reviews"]:
        rm = re.search(r"([\d.]+\s*[KMB]?)\s*reviews?", html, re.I)
        if rm:
            result["total_reviews"] = rm.group(1).strip()

    # Description: "About this app" section or long text in script
    for node in sel.css("div.bARER, div.htlgb, div[data-item-id='description'], div.DWPxHb"):
        t = (node.get_all_text() or "").strip()
        if "About this app" in t:
            t = t.replace("About this app", "").strip()
        if len(t) > 100 and "report" not in t.lower():
            result["description"] = t[:50000]
            break
    if not result["description"]:
        dm = re.search(r"About this app\s*</[^>]+>\s*</[^>]+>\s*<[^>]+>([^<]{200,})", html, re.DOTALL)
        if dm:
            result["description"] = re.sub(r"\s+", " ", dm.group(1)).strip()[:50000]

    # Screenshot URLs: img in carousel or from script
    for node in sel.css("img[data-screenshot], img.T75of[src*='googleusercontent'], img[alt][src*='screenshot']"):
        attrib = getattr(node, "attrib", None) or {}
        src = attrib.get("src") or attrib.get("data-src")
        if src and "googleusercontent" in src and src not in result["screenshot_urls"]:
            result["screenshot_urls"].append(src)
    if not result["screenshot_urls"]:
        from_script = _extract_from_script(html)
        result["screenshot_urls"] = list(from_script.get("screenshot_urls", []))[:20]

    return result
