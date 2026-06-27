# Reflo — Quiz Generation Prompt (v1)

This is the ask sent to the model for the **Quiz** brain trip. In goes one
chapter's text. Out come a handful of multiple-choice questions whose wrong
answers are real traps. This is the part of the app that lives or dies here, so
the prompt says plainly what a good trap is rather than hoping the model guesses.

Treat this as a living document. Run it on a real chapter, read the questions it
makes, and let the bad ones tell you what to fix.

Placeholders to fill in: `{{BOOK_TITLE}}`, `{{CHAPTER_TEXT}}`, `{{NUM_QUESTIONS}}`
(start with 5).

---
## Prompt
Prompt available here - [prompts/questions.md](../prompts/questions.md)

---

## One worked example of the standard (for your eye, not part of the prompt)

A single question that meets the bar, drawn from *Thinking in Systems*, to show
what "every option live" and "three depths" look like in practice:

**Stem:** A city keeps widening a congested highway, but within two years
traffic crawls just as badly as before each expansion. Which best explains why?

- **A — correct.** The extra room changes how people choose: more of them drive,
  and drive farther, until the road is as full as people will put up with again.
  *(The systems answer — a balancing loop — said plainly, with no jargon to give
  it away.)*
- **B — false belief.** The widening simply wasn't big enough; a few more lanes
  would finally clear it. *(The exact "push harder on the obvious lever" intuition
  the chapter overturns. Tempting, shallow.)*
- **C — flawed model.** The real cause is population growth — more people moved
  in, so of course traffic came back. *(A coherent single-cause worldview;
  plausible, internally consistent, but pins it on an outside cause instead of the
  system's own feedback.)*
- **D — wrong category.** A given road width carries a fixed amount of traffic,
  so congestion was bound to return to that fixed level. *(Treats congestion as a
  static property of the road rather than a changing pattern produced by drivers'
  choices. A relationship mistaken for a fixed thing.)*

Notice no option is dismissable on sight, the correct one isn't the longest or
the most technical, and ruling each wrong one out requires actually understanding
the idea — which is the whole point.

---

## Notes for tuning (not part of the prompt)

- **Question count.** Start at 5. If quizzes feel thin or bloated, change the one
  number.
- **If traps come out lazy,** the usual cause is the model skipping the "name the
  belief it overturns" step. Strengthen that instruction before anything else —
  naming the misconception is the single highest-leverage line in the prompt.
- **If the correct answer keeps standing out,** push harder on flattening: state
  the length/tone/vocabulary-parallel rule more forcefully, or have the model
  re-read its four options and rewrite any that betray the answer.
- **Expect roughly half the traps to land** on a first pass — that matches what's
  known about generated distractors. The narration step is what carries the real
  weight, so the quiz doesn't have to be perfect to be useful.
- **The `core_ideas`, `misconception`, `depth`, and `note` fields** are for you to
  audit quality while tuning. The app can ignore them when rendering; they cost
  almost nothing and make every question's reasoning visible.