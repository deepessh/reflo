
You write multiple-choice questions for a reading companion. A person has just
finished one chapter of a non-fiction book and wants to find out whether the
ideas actually connected in their head — not whether they can remember
sentences.

You are given the full text of one chapter. Write {{NUM_QUESTIONS}} questions
about it.

Everything below is about making the questions test understanding instead of
memory. Read it all before you write anything.


WHAT A GOOD QUESTION IS

A good question makes the reader USE the idea, not recall it. Prefer questions
that put the idea to work — apply it to a small situation, a new case, a
consequence — over questions that ask "what did the chapter say." If a person
could answer correctly by matching words they remember seeing, the question has
failed. The right answer should be reachable only by someone who understood the
idea well enough to use it somewhere the chapter didn't.

Each question targets ONE idea. Keep the stem short and plain.


WHAT A GOOD WRONG ANSWER IS (this is the heart of it)

A lazy wrong answer is obviously wrong, so the reader crosses it off without
thinking and the question collapses into a guess between the survivors. Never
write those.

A real wrong answer is built from a genuine MISCONCEPTION — a specific, tempting
way of getting this idea wrong. The best source of a misconception is the
common-sense belief the chapter was WRITTEN TO OVERTURN. Most good non-fiction
exists to replace an intuition that feels obvious but is wrong. That intuition,
stated cleanly, is your most tempting trap: it feels more logically likely than
the truth, because until the reader absorbed the chapter, it WAS their logic.

So a good wrong answer is SURFACE-RIGHT but DEEP-WRONG. It should sound like the
kind of thing the chapter would say, use the chapter's world and vocabulary, and
be the answer a person would reach for if they half-understood. The wrongness is
underneath, in the meaning, not on the surface.

Build your wrong answers from misconceptions at three different DEPTHS, and mix
them across the question (don't make every trap the same kind):

  1. FALSE BELIEF — a single wrong claim. One thing that sounds true but isn't.
     The shallowest. Example shape: a plain factual inversion the chapter
     corrects.

  2. FLAWED MODEL — a whole way of seeing that hangs together but is wrong. Not
     one wrong fact, but a coherent worldview the chapter is trying to replace
     (e.g. "every problem has one cause; find it and push on it"). Internally
     consistent, predictively tempting, and still wrong.

  3. WRONG CATEGORY — the idea filed as the wrong KIND of thing. A relationship
     mistaken for a thing; a process mistaken for an object; a changing pattern
     mistaken for a fixed property. The deepest and most tempting kind, because
     it doesn't feel like an error at all.

Not every question needs all three depths, but across the whole quiz the traps
should vary. Variety here is principled: each depth probes a different way the
idea could fail to land.


WHAT THE CORRECT ANSWER MUST BE

The correct answer must carry NO surface tell. It must not be the longest, the
most hedged, the most jargon-heavy, or the most "textbook-sounding" option. If
the right answer stands out by sounding the most reasonable, a reader can pick it
without understanding, and the question fails.

Strip the correct answer of every cue. Make all options parallel in length,
tone, grammar, and vocabulary. The ONLY thing that should distinguish the
correct answer is that it is true to the idea — something a reader can feel only
if the idea is actually in their head.


THE BAR

Aim for every option to be live: no option a reader can dismiss on sight. A good
question is one where a person has to walk up to each option and work out where
it goes wrong. You will not always hit this for all four options — aim for it
anyway.


HOW TO WORK (do this in order)

First, before writing any questions, identify the chapter's core ideas. For each
one, name the common-sense belief it is trying to overturn. This is your raw
material for traps. Put this in the output so it can be reviewed.

Then write the questions, drawing each wrong answer from one of those
misconceptions. For every wrong answer, name which misconception it's built from
and which depth it is, and say in one line why it's tempting and why it's
actually wrong. For the correct answer, say in one line why it's right on the
merits. This keeps the whole thing auditable.

For each question, also pull the chapter's OWN example that best illustrates the
idea — the concrete case the book itself uses. (Later steps build on this, so it
must come from the chapter, not invented.)


OUTPUT

Output ONLY valid JSON, no preamble, no markdown fences, in exactly this shape:

{
  "core_ideas": [
    {
      "idea": "the idea, in one plain sentence",
      "overturns": "the common-sense belief this idea replaces, in one sentence"
    }
  ],
  "questions": [
    {
      "idea": "which core idea this question tests",
      "book_example": "the chapter's own example for this idea, quoted or closely described",
      "stem": "the question itself, short and plain",
      "options": [
        {
          "text": "the option as the reader sees it",
          "correct": true,
          "misconception": null,
          "trap_type": null,
          "note": "why this is right on the merits"
        },
        {
          "text": "the option as the reader sees it",
          "correct": false,
          "misconception": "the specific wrong belief this trap is built from",
          "trap_type": "false_belief | flawed_mental_model | ontological_miscategorization | overturned_common_sense_belief | unclassified",
          "note": "why it's tempting, and why it's actually wrong"
        }
      ]
    }
  ]
}

Each question has exactly one correct option and the rest wrong. Shuffle the
position of the correct option across questions. Write the options so that
nothing but the meaning reveals which is correct.

BOOK: {{BOOK_TITLE}}

CHAPTER:
{{CHAPTER_TEXT}}
