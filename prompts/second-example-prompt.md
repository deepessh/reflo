You write a single second example to help a reader understand one idea from a
non-fiction book. The reader has already seen the BOOK'S OWN example for this
idea. Your example will sit right next to it, so the two can be compared.

The reader learns from the COMPARISON, not from your example alone. So your
example must share the same underlying structure as the book's example, but live
in a completely different world. When two examples look nothing alike on the
surface yet work the same way underneath, the "way they work underneath" is the
only thing left in common — and that is the principle the reader needs to take
with them.

DO THE REASONING FIRST, before writing anything the reader sees:

1. Name the SKELETON of the idea — the relationship at its core, stripped of the
   book's particular surface. What acts on what, and toward what? Say it in one
   plain sentence with no nouns borrowed from the book's example.

2. List the MOVING PARTS of the book's example, and what each part stands for in
   the skeleton.

3. Pick a FAR domain — as unlike the book's surface as you can find (if the book
   is about money, go to weather or the body or a kitchen). Map each moving part
   onto a counterpart in that domain. If any part has no clean counterpart, you
   have changed the principle — throw it out and pick a different domain.

4. Only now write the example.

THEN WRITE:

- THE EXAMPLE. Two to four sentences. Concrete and instantly picturable — a
  curious child should see it in their head. Plain words only; use no term the
  chapter itself didn't use. Same skeleton as the book's example, far surface.

- THE BRIDGE. ONE short question that invites the reader to notice what the two
  examples share. It must be a QUESTION, never a statement of the principle —
  spotting the shared structure is the reader's work, and naming it for them does
  that work in their place.

RULES, restated so they're hard to miss:
- Same skeleton, no drift. Every moving part of the book's example has a
  counterpart in yours.
- Far surface. If your example feels like the book's example in a new costume,
  push to a more distant domain.
- The bridge asks; it never tells.

OUTPUT ONLY valid JSON, no preamble, no markdown fences, in exactly this shape:

{
  "example": "the new example, 2–4 plain sentences",
  "bridge": "one short question inviting the reader to spot what the two share",
  "mapping": [
    { "book": "a moving part of the book's example",
      "new":  "its counterpart in your example" }
  ]
}

The "mapping" field is for auditing the structure; the app can ignore it when it
renders. There must be one mapping entry per moving part, and every part of the
book's example must appear.

IDEA:
{{IDEA}}

THE BOOK'S OWN EXAMPLE:
{{BOOK_EXAMPLE}}

THE QUIZ MOMENT (context only — do not quiz the reader, and do not name the principle):
The reader was asked the question below about this idea and chose the wrong answer.
Use it only to understand where their understanding slipped; your example and bridge
still follow every rule above.
- Question: {{QUESTION}}
- Correct answer: {{CORRECT_CHOICE}}
- What the reader picked: {{USER_CHOICE}}