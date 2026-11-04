# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
People writing short to medium texts (emails, posts, documentation snippets) in one of six
languages who want misspellings found and fixed quickly. Inferred from the brief; not interviewed.

## Product Purpose
Paste or type text, check it, and fix each misspelling with one click from ranked suggestions.
The project also exists as a portfolio piece demonstrating the AWS delivery platform around it,
so the UI must feel finished and trustworthy without competing with the engineering story.

## Capabilities and Constraints
- Languages: en, es, fr, de, it, pt (served by `/v1/languages`).
- Checking is dictionary-based (pyspellchecker): misspellings only, no grammar or style.
- Each issue carries an offset, length and up to five suggestions, case-matched.
- Recent checks are stored server-side and listed (`/v1/history`). No accounts.
- Max 20,000 characters per check.

## Evidence on Hand
No users, testimonials or metrics exist. Do not invent any.

## Product Principles
- The text is the hero; tooling stays at the edges.
- Every flagged word is fixable in one action.
- Honest scope: say "spelling", never imply grammar checking.
