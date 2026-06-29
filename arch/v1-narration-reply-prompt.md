# Reflo — Narration Reply Prompt (v1 draft)

The hardest of the four brain calls. After the quiz, the reader says out loud, in
their own words, what they took from the chapter. This call reads that spoken
summary against the chapter and replies in words — warm first, then honest, no
score.

**In:** the reader's transcribed summary + the full chapter text.
**Out:** a few sentences of plain spoken-feeling reply.
**Not passed in v1:** the quiz answers (kept simple, per the shell doc).

This is a living document — tune it against real chapters, don't perfect it on
paper.

---

## The sendable prompt
[prompts/narration-reply.md](../prompts/narration-reply.md)

---

## About the embedded example

The example now lives *inside* the sendable prompt as a few-shot demonstration —
study it, then do the same — which steadies the tone better than rules alone. Two
things to know about it:

- **It's an illustrative stand-in, not a quotation.** The example "chapter" is
  written in plain language, not lifted from any book, so the prompt carries no
  copyrighted text.
- **The reader's summary in it is deliberately wrong in one specific way** — it
  flips reinforcing and balancing loops. That's the *reversed-relationship* case
  from rule 1, so the example demonstrates catching a real gap (as a question),
  not just praising. The reply opens on a true connection, catches the one flip,
  offers an example without pushing, and lands in four sentences.

*Trade-off:* the example adds tokens to every narration-reply call. For
personal-use scale that's nothing, and the consistency is worth it early. If the
model's tone holds steady once you've tuned it, you can strip the example back out
to save tokens.

---

## Tuning notes

- **False corrections are the expensive failure.** Test rule 2 hardest: feed it a
  summary that's *correct but unusual* (a right idea phrased in a way the chapter
  didn't) and confirm the model doesn't "correct" it. A missed gap costs a little;
  a confident wrong correction teaches something false and burns trust.
- **Wording-slip vs reversed-relationship.** The split inside rule 1 is the catch
  the app exists for. Test both: a right idea in mangled words (should pass clean)
  and a cleanly-worded *backwards* claim (should get caught). The worked-example
  narration is the second kind — the reader flips reinforcing and balancing.
- **Compliment-sandwich smell.** If the opener reads as filler ("nice work
  thinking about this"), it failed rule 4. The opener must point at a specific
  link or be cut.
- **Re-lecture creep.** Biggest tone risk, because the model holds the whole
  chapter. If replies start summarizing the chapter back, tighten rule 7 or trim
  the chapter passed in.
- **The "but" reflex.** Check that a near-perfect summary sometimes gets pure
  affirmation. If every reply has a turn, rule 8 isn't landing.
- **Sameness over time.** Praise-then-nudge is itself a shape the reader will
  clock by chapter three. Watch for it across a run of chapters; if it feels
  formulaic, add a light "vary how you open" instruction rather than a new rule.
- **Length.** Aim 3–6 sentences. If it sprawls, harden rule 11.
- **Read on screen or aloud?** The spec says the app "talks back" and to "show the
  narration reply" — confirm whether this is on-screen text or text-to-speech. If
  it's text-only, the "sounds like a person" constraint can relax and questions
  can be tighter; if spoken, keep it as-is.
- **Quiz results stay out.** Per the shell doc, this call doesn't see taps. If you
  later want "you said X but you also missed the X question," that's a v2 seam.
