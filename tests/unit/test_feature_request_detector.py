from api.procedures.feature_request_detector import has_feature_request


def test_has_feature_request_returns_true_for_request_phrases() -> None:
    text = "I love this app, but could you add a dark mode setting?"
    assert has_feature_request(text) is True


def test_has_feature_request_returns_true_for_feature_request_literal() -> None:
    text = "Feature request: add custom reminders please."
    assert has_feature_request(text) is True


def test_has_feature_request_returns_false_for_non_request_text() -> None:
    text = "I use this every day and it works well for me."
    assert has_feature_request(text) is False


def test_has_feature_request_returns_false_for_blank_or_short_text() -> None:
    assert has_feature_request("") is False
    assert has_feature_request("   ") is False
    assert has_feature_request("add") is False
