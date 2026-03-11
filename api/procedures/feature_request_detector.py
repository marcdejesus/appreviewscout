"""
Detect if a review contains a feature request for market research.
Used to flag reviews that suggest new features or settings (market gaps).
"""

import re
from typing import List, Tuple

# Phrases that often indicate a feature request or suggestion
FEATURE_REQUEST_PATTERNS: List[Tuple[str, int]] = [
    # (pattern, min length to avoid false positives on very short text)
    (r"\b(add|adding)\s+(a\s+)?(setting|option|feature|toggle)\b", 20),
    (r"\b(would\s+be\s+nice\s+to|would\s+love\s+to\s+see)\b", 15),
    (r"\b(wish\s+(there\s+was|you\s+(could|would)|they\s+had|we\s+could))\b", 15),
    (r"\b(could\s+you\s+add|please\s+add|can\s+you\s+add)\b", 15),
    (r"\b(suggest\s+adding|suggestion:\s*|suggest\s+that)\b", 15),
    (r"\b(hope\s+(they\s+)?(add|will\s+add)|hoping\s+for)\b", 15),
    (r"\bfeature\s+request\b", 10),
    (r"\b(it\s+would\s+be\s+great\s+if|it\'d\s+be\s+great\s+if)\b", 15),
    (r"\b(option\s+to\s+|setting\s+to\s+)\b", 15),
    (r"\b(allow\s+users?\s+to|let\s+users?\s+)\b", 15),
    (r"\b(should\s+add|need\s+to\s+add|needs?\s+(a\s+)?(setting|option))\b", 15),
    (r"\b(replace\s+[\"\']?\w+[\"\']?\s+with|choose\s+to\s+replace)\b", 20),
    (r"\b(if\s+only\s+(it\s+)?(could|had|would))\b", 15),
    (r"\b(missing\s+(\w+\s+)?(feature|option|setting))\b", 15),
    (r"\b(would\s+improve\s+if|could\s+improve\s+by\s+adding)\b", 20),
]

COMPILED = [(re.compile(p, re.IGNORECASE), min_len) for p, min_len in FEATURE_REQUEST_PATTERNS]


def has_feature_request(text: str) -> bool:
    """
    Return True if the review text appears to contain a feature request or suggestion.
    Uses keyword/phrase heuristics to flag potential market gaps.
    """
    if not text or not text.strip():
        return False
    combined = " ".join(text.split())
    if len(combined) < 10:
        return False
    for pattern, min_len in COMPILED:
        if len(combined) >= min_len and pattern.search(combined):
            return True
    return False
