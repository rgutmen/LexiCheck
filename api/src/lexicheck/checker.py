import re
from dataclasses import dataclass
from functools import lru_cache

from spellchecker import SpellChecker

SUPPORTED_LANGUAGES = ("en", "es", "fr", "de", "it", "pt")

# Letters (including accented ones) and inner apostrophes: "don't", "l'eau".
WORD_RE = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)*", re.UNICODE)


@dataclass(frozen=True)
class Issue:
    word: str
    offset: int
    length: int
    suggestions: list[str]


@lru_cache(maxsize=len(SUPPORTED_LANGUAGES))
def _dictionary(language: str) -> SpellChecker:
    # Loading a dictionary costs ~100ms, so keep one per language for the process lifetime.
    return SpellChecker(language=language)


def check_text(text: str, language: str, max_suggestions: int = 5) -> list[Issue]:
    if language not in SUPPORTED_LANGUAGES:
        raise ValueError(f"unsupported language: {language}")
    spell = _dictionary(language)

    matches = list(WORD_RE.finditer(text))
    unknown = spell.unknown(m.group(0).lower() for m in matches)

    issues: list[Issue] = []
    for match in matches:
        word = match.group(0)
        if word.lower() not in unknown or len(word) == 1:
            continue
        candidates = spell.candidates(word.lower()) or set()
        ranked = sorted(candidates, key=lambda w: -spell.word_usage_frequency(w))
        issues.append(
            Issue(
                word=word,
                offset=match.start(),
                length=len(word),
                suggestions=[_match_case(word, s) for s in ranked[:max_suggestions]],
            )
        )
    return issues


def _match_case(original: str, suggestion: str) -> str:
    if original.isupper():
        return suggestion.upper()
    if original[0].isupper():
        return suggestion.capitalize()
    return suggestion
