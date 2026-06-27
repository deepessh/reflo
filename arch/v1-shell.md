# Reflo — Shell Implementation Doc (No Brain)

This doc describes the **empty shell** of Reflo: every room of the app stood up
and walkable, with no language model wired in yet. The goal is a thing that
*runs* — you can add a book, browse chapters, walk through a quiz screen, and
record your narration — even though nothing is *thought* yet. The calls that
would reach a model are stubbed and return placeholder data.

Build the shell first. Let it tell you what it needs. The muscle (the actual
asks to the model) goes in later, against a shell that already works.

---

## The architecture in one breath

The phone is almost the entire app. It holds your books, cracks them open to
find chapters, shows you everything, and listens to you. A rented brain — called
only when needed — does the hard thinking. The only thing that survives between
sessions is your library of books. In the shell, the brain is not connected; its
four calls are stubbed.

A five-year-old version: *it keeps your books, will ask a smart computer to make
a quiz, listens to you explain, and tells you what it heard.*

---

## Build target

- **Platform:** Native iPhone, Swift / SwiftUI
- **Built on:** macOS (Xcode)
- **Why native:** the two tricky pieces — cracking the EPUB and turning voice to
  text — are first-class and built into the platform, so the shell snags least
  exactly where it otherwise would.
- **Scope:** Personal use only. No accounts, no backend, no stored history.

---

## What lives where

| Concern | Home | Notes |
|---|---|---|
| Library of EPUBs | The phone | The **only** thing that persists between sessions |
| Cracking the EPUB / finding chapter boundaries | The phone | Book already lives here; nothing extra travels |
| Showing books, chapters, quiz, feedback | The phone | All UI is on-device |
| Voice → text | The phone | Built-in, on-device; **gist is enough**, rough is fine |
| Making quiz questions / traps | Rented brain (stubbed in shell) | One chapter's text goes out |
| Mending paragraph on a miss | Rented brain (stubbed in shell) | Fetched only on a miss |
| Second example | Rented brain (stubbed in shell) | Fetched only on demand |
| Narration reply | Rented brain (stubbed in shell) | Your words + the chapter go out |

**Nothing on any brain trip is stored.** Quiz, taps, narration, feedback —
shown, then gone. Only the books remain.

---

## The four brain trips (stubbed in the shell)

These define the seams. In the shell, each is a function that returns canned
placeholder data instantly, so the UI can be built and walked end to end. The
real asks get written later.

1. **Quiz** — *in:* one chapter's text. *out:* a list of questions, each with
   choices, the correct choice marked, and the book's own example.
2. **Mending paragraph** — *in:* the missed question. *out:* a short paragraph
   that finishes the half-formed thought. **Fetched only on a miss.**
3. **Second example** — *in:* the relevant idea. *out:* one more example, to sit
   *next to* the book's example. **Fetched only on demand (a button).**
4. **Narration reply** — *in:* your spoken summary (as text) **plus the full
   chapter**. *out:* warm-then-honest words, no score. **Carries the chapter, not
   your quiz answers** (keeping it simple for v1).

Define each as a clean Swift protocol/interface now, with a `Stub`
implementation. Swapping in the real `Model` implementation later should touch
nothing but the wiring.

---

## Screens to build (the walkable shell)

1. **Library** — list of books the user has added; a button to add a new EPUB.
   Persists across launches. Empty state on first run.
2. **Add a book** — pick an EPUB from Files; it gets copied into the app's local
   storage and appears in the library.
3. **Chapters** — tap a book → see its chapter list (from the EPUB's own table of
   contents, the same one printed in the physical copy). Tap a chapter → a
   **Start Quiz** button.
4. **Quiz** — walk the questions. Tap a choice. On a miss, show the mending
   paragraph (stubbed) and a **Show me another example** button (stubbed). No
   score, no progress bar, nothing gamified.
5. **Narrate** — after the quiz, record a short spoken summary; transcribe to
   text on-device.
6. **Feedback** — show the narration reply (stubbed). Words only. Then back to
   the chapter list; the user can tap any earlier chapter to quiz it again.

---

## The whole loop (what the shell walks through)

1. Add a book (upload an EPUB).
2. Open the book → confirm the chapter list matches the physical copy.
3. Tap the chapter just finished → app grabs the text from that chapter's start
   to the next.
4. Quiz: a handful of multiple-choice questions (stubbed).
5. Tap an answer; on a miss, a mending paragraph + optional second example
   (stubbed).
6. Narrate a short spoken summary out loud (transcribed on-device).
7. App talks back in words, no score (stubbed).

Come back any time and tap an earlier chapter to quiz it again — same mechanism.

---

## Locked decisions carried in from the spec

- **EPUB only.** Real text, defined reading order, built-in chapter list.
- **Unit of reading is the chapter,** chosen by tapping the book's own TOC.
- **Non-fiction focus.**
- **Multiple choice, trap-based** wrong answers (the asks, written later, are
  where this lives or dies).
- **Mending paragraph on a miss,** built around the book's own example.
- **Second example on demand,** appearing next to the book's example.
- **Spoken narration, required,** after the quiz.
- **Feedback: words only,** about the thinking not the person, nudges as
  questions, encouragement-then-honesty. No score, no gamification.
- **Quiz any earlier chapter,** free, same mechanism.

## Deferred — explicitly NOT in the shell (and mostly not in v1)

- **The model itself** — the shell stubs all four calls; picking and wiring a
  model is the next step after the shell runs.
- **The asks** — the actual wording sent to the model. The heart of quality;
  written against a working shell.
- **Any stored history** — no saved answers, no scoring over time, no spaced
  repetition, no auto-resurfacing. (Long-term plan, deliberately parked.)
- **PDFs / other formats.**
- **Pointing back to the exact source spot** of a question.
- **Active steering** on a detected gap.

---

## Honest hard parts to expect (not blockers)

- **Messy EPUBs.** Most are clean; some have odd chapter lists. When a book is
  built oddly, the "tap a chapter" experience gets odd too. Acceptable for v1 —
  but the EPUB parsing on the phone is where this roughness shows up, so expect
  to handle imperfect tables of contents gracefully.
- **On-device transcription is gist-level.** That's fine by design — the reply
  (later) only needs meaning, not word-for-word. Don't over-engineer the voice
  step.

---

## Definition of done for the shell

You can, on your own iPhone:

1. Add an EPUB and see it persist in your library across app launches.
2. Open it and see a chapter list drawn from the EPUB's own TOC.
3. Tap a chapter and reach a quiz screen showing placeholder questions.
4. Tap answers; on a miss, see a placeholder mending paragraph and a working
   (placeholder-returning) "another example" button.
5. Record a spoken summary and see it transcribed to text.
6. See a placeholder narration reply, then return to the chapter list.

When all six walk end to end with stubs, the shell is done — and it's ready for
the muscle.