from __future__ import annotations

import sys
import types


def _install_fake_scrapling_modules() -> None:
    if "scrapling.fetchers" in sys.modules and "scrapling.parser" in sys.modules:
        return

    scrapling_module = types.ModuleType("scrapling")
    fetchers_module = types.ModuleType("scrapling.fetchers")
    parser_module = types.ModuleType("scrapling.parser")

    class _Fetcher:
        @staticmethod
        def get(*args, **kwargs):  # type: ignore[no-untyped-def]
            raise RuntimeError("network calls are disabled in unit tests")

    class _StealthyFetcher:
        @staticmethod
        def fetch(*args, **kwargs):  # type: ignore[no-untyped-def]
            raise RuntimeError("browser calls are disabled in unit tests")

    class _Selector:
        def __init__(self, *args, **kwargs):  # type: ignore[no-untyped-def]
            pass

    fetchers_module.Fetcher = _Fetcher
    fetchers_module.StealthyFetcher = _StealthyFetcher
    parser_module.Selector = _Selector

    sys.modules["scrapling"] = scrapling_module
    sys.modules["scrapling.fetchers"] = fetchers_module
    sys.modules["scrapling.parser"] = parser_module


_install_fake_scrapling_modules()

from api.procedures.play_app_metadata import parse_play_store_url


def test_parse_play_store_url_returns_id_for_valid_url() -> None:
    url = "https://play.google.com/store/apps/details?id=com.example.app&hl=en"
    assert parse_play_store_url(url) == "com.example.app"


def test_parse_play_store_url_returns_none_for_non_details_path() -> None:
    url = "https://play.google.com/store/apps"
    assert parse_play_store_url(url) is None


def test_parse_play_store_url_returns_none_when_missing_id() -> None:
    url = "https://play.google.com/store/apps/details?hl=en"
    assert parse_play_store_url(url) is None


def test_parse_play_store_url_trims_package_id() -> None:
    url = "https://play.google.com/store/apps/details?id= com.example.trimmed "
    assert parse_play_store_url(url) == "com.example.trimmed"
