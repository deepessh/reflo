# Test EPUB fixtures

## Committed

- **`sample.epub`** — Project Gutenberg *Alice's Adventures in Wonderland* (EPUB 3). Used by unit tests and manual QA.

## Local-only (gitignored)

Obtain these on your machine for broader manual testing; do not commit large files.

1. **Nested TOC** — Standard Ebooks or any non-fiction with multi-level nav.
2. **Broken/minimal TOC** — EPUB with empty or missing nav; exercises spine fallback.

Place additional `.epub` files in this folder; they are gitignored except `sample.epub`.
