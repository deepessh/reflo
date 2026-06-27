# Reflo — Second Example Prompt (v1)

The third brain trip. The reader has tapped **"show me another example."** This
prompt makes ONE new example to sit *next to* the book's own — so the reader can
compare the two and see the principle underneath.

The whole feature rests on one finding: **two examples compared beat one alone.**
But only if the two share the same skeleton and differ on the surface. If the new
example feels like the book's example reworded, the reader learns nothing new. If
it drifts to a different principle, the comparison teaches the wrong thing. So the
prompt's job is narrow and exact: *same skeleton, far surface.*

Treat this as a living document. Run it on real chapters, watch where the examples
come out too close or quietly off-principle, and sharpen the line that's slipping.

---

## What goes in and what comes back

**In:** the idea being illustrated, plus the book's own example for it. (Both are
already produced by the quiz trip — `idea` and `book_example` — so the app just
hands them along. No new work upstream.)

**Out:** one new example, far from the book's surface, built on the same skeleton;
a one-line bridge that *invites* the reader to spot what the two share; and an
audit field so you can check the structures actually match while tuning.

---

## The sendable prompt

[prompts/second-example-prompt.md](../prompts/second-example-prompt.md)

---

## One worked example of the standard (for your eye, not part of the prompt)

Drawn from *Thinking in Systems*, to show what "same skeleton, far surface" looks
like when it lands.

**Idea:** A balancing feedback loop holds something near a goal — it senses the
gap between where things are and where they should be, and acts to close it.

**Book's example:** A thermostat and a room. When the room drifts below the set
temperature, the furnace switches on and warms it back up; it never sits perfectly
still, always correcting around the target.

**The example that comes back:**
> Steering a car down a straight lane. The car drifts a little left, the driver
> feels it and nudges right; it drifts a little right, they nudge left. The wheel
> is never still — it's a constant stream of small corrections holding the car
> near the middle of the lane.

**The bridge:**
> What do a furnace warming a chilly room and a driver nudging a drifting car back
> to center have in common?

**The mapping (audit):**

| book | new |
|---|---|
| room temperature | car's position in the lane |
| the set temperature | the middle of the lane |
| the thermostat sensing the gap | the driver feeling the drift |
| the furnace switching on | steering back toward center |
| settling near the target, never still | constant small corrections, never still |

Far surface (a warm house vs. a moving car), identical skeleton (sense the gap →
act to close it → never perfectly still). The bridge points at the shared
structure without naming "balancing feedback loop" — that recognition is left for
the reader.

---

## Tuning notes

- **Surface distance is the main dial.** If the new examples feel like the book's
  example reworded, the "far domain" step is being skipped — make step 3 louder,
  or hand it a banned-domain hint. If they feel random and unrelated, the skeleton
  isn't being preserved — tighten the mapping rule.

- **Watch for quiet principle-drift.** The classic failure is an example that
  *feels* similar but actually runs on a different mechanism. The `mapping` field
  is your tripwire: if a part of the book's example has no honest counterpart, the
  model changed the principle. That's the first thing to read when a pair feels
  off.

- **The bridge is doing real work.** If it reads as a statement dressed up with a
  question mark, or if it only describes one of the two examples, fix that before
  anything else — a bad bridge quietly turns the feature back into "here's a second
  thing to read."

- **Test against a chapter where the book's example is itself weird** or
  domain-specific. That's where the far-domain mapping strains and where you'll
  see whether the prompt holds.