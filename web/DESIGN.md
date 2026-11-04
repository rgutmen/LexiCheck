# Design

## World
A copy editor's desk. Warm paper, black ink, and the vermilion of a proofreader's
pencil. The text being checked is set like a manuscript (serif, generous leading);
the tool around it is a quiet sans. Corrections live in the margin, the way an
editor annotates a galley proof.

## Tokens
| Token | Light | Dark | Use |
|---|---|---|---|
| `--paper` | #F7F2E8 | #1B1915 | page ground |
| `--sheet` | #FFFDF8 | #23201B | the manuscript surface |
| `--ink` | #1F1B16 | #EDE6D8 | primary text, primary button |
| `--ink-2` | #5C544A | #B4AB9C | secondary text (>= 4.5:1 on paper) |
| `--rule` | #E2D8C6 | #3A352D | hairlines |
| `--mark` | #B9381F | #F07A5E | misspelling marks, focus, accent |
| `--mark-wash` | #F8E0D7 | #4A2A22 | active mark background |
| `--ok` | #3B6A47 | #8CC59A | clean-copy state |

## Type
- Manuscript: Newsreader Variable, 19px/1.75, optical sizing on.
- Interface: Instrument Sans Variable, 14-15px. Numbers use tabular figures.
- Wordmark: Newsreader 600 with a vermilion wavy underline.

## Shape and depth
Sheet radius 14px, controls 10px, chips are pills. One elevation: the sheet carries
a soft offset shadow; everything else is flat on hairlines.

## Motion
One authored moment: after a check, the marks draw in (underline wipes left to
right, staggered). Everything else is instant or a 150ms ease-out. Respects
`prefers-reduced-motion`.

## Icons
lucide-react, 1.75 stroke, 16-18px.
