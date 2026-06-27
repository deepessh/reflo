# Reflo — Mending Text Prompt (v1)

Brain trip #2. Fires **only on a miss**. Input is the question the reader got
wrong (plus the book's own example, which the quiz call already carried).
Output is **one short paragraph** that finishes the half-formed thought and
mends the idea.

This is a living document. Tune it against real chapters, not on paper.

---

## What this paragraph has to do

The reader picked a *trap* — a specific, tempting way of misreading the chapter.
The most tempting trap is usually the common-sense belief the chapter was written
to overturn. So the mend isn't "here's the right answer." It's:

1. Make the wrong idea feel **reasonable** — name why a smart person would think it.
2. Show **where that thinking breaks**.
3. Make it click using **the book's own example** (no new examples here — that's a
   separate button).
4. Optionally end with a light **question**, not a verdict.

All of this stays about the *thinking*, never about the person.

---

## The sendable prompt

Available in [prompts/mending.md](../prompts/mending.md)

`{{misconception_label}}` is the highest-leverage input if you have it (see
tuning notes). If your quiz call doesn't export it, just delete that line — the
prompt still works, the model just re-infers the misconception from the wrong
choice.

---

## Worked example (Thinking in Systems)

**Input**

- CHAPTER: *Thinking in Systems* — "The Basics"
- QUESTION: A government cuts its spending. Why might the national debt keep
  rising for years afterward?
- CHOICES:
  - A) Because cutting spending should make debt fall right away, so something
       else must be adding to it.
  - B) Because a debt is a stock, and a stock keeps rising as long as more flows
       in than out — even after the inflow shrinks.
  - C) Because debt is unrelated to yearly spending.
- CORRECT: B
- THE READER PICKED: A
- MISCONCEPTION: Treats a change in a *flow* as an instant change in the *stock*
  (flawed mental model — stock and flow collapsed into one thing).
- BOOK'S EXAMPLE: a bathtub — the water level is a stock; the faucet and drain
  are flows.

**Target output**

> It feels obvious that spending less should shrink the debt. But a debt is a
> stock — like the water level in a bathtub — and a stock changes only through
> its flows. Cutting spending narrows the faucet, yet as long as more pours in
> than drains out, the level still rises, just slower. The debt only falls once
> what leaves beats what arrives. So the real question isn't "did we spend
> less?" — it's "is more now leaving than coming in?"

Note what it does: validates the instinct, breaks it on the structure, rides the
book's bathtub the whole way, no praise. This one ends on a question — the next
one doesn't. Both are fine; let the idea decide.

### Second worked example (ends flat — no question)

**Input**

- CHAPTER: *Thinking in Systems* — "A Brief Visit to the Systems Zoo"
- QUESTION: Why does nudging a delayed shower often swing the temperature between
  too hot and too cold?
- THE READER PICKED: Because the plumbing is faulty, or you're adjusting it wrong.
- CORRECT: Because the delay between turning the knob and feeling the change makes
  you react to old information and overcorrect.
- MISCONCEPTION: Blames the person or the parts for behavior the *structure* (a
  delay in the loop) produces.
- BOOK'S EXAMPLE: a shower where the hot water arrives a few seconds after you
  turn the knob.

**Target output**

> It's natural to blame the plumbing or your own hand. But the swinging comes
> from the *delay* between turning the knob and feeling the result. Because the
> new temperature takes a moment to arrive, you keep reacting to old information
> and overcorrecting — too hot, then too cold, then too hot. The fault isn't the
> pipes or your skill; it's the lag in the loop, which is why smaller, patient
> adjustments settle it and bigger ones don't.

Same shape, no closing question — it just lands on the corrected picture.

---

## Tuning notes

- **Misconception label = biggest lever.** When the quiz call names the
  misconception behind each distractor, the mend can speak straight to the exact
  wrong turn the reader took. This is the single thing most worth wiring through
  from the quiz output into this call.
- **Watch for sneaky praise.** "Never about the person" is easy to violate —
  models drift into "great instinct!" Scan early outputs for it.
- **Watch for invented examples.** The "no new facts" rule matters; if the model
  borrows a fresh analogy instead of the book's, tighten the rule or feed a
  little more of the example.
- **The closing question** is a coin-flip per chapter — sometimes it sharpens,
  sometimes it nags. Leave it optional and judge from real outputs.
- **Length** is set short on purpose. If mends feel thin, loosen the word cap
  before adding structure — keep it one paragraph.
