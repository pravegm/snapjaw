# Snapjaw scorecard (founder rubric, from 28 Oct 2026)

The founder's ask: "have critics score the app on design, ease, willingness to pay and all, and based on that do
iterations". Every round from R6 on is scored on this card by the same panel, so the numbers can be compared round to
round. A round's brief is built from the **lowest-scoring dimensions first**.

## The panel (fixed personas; each scores every dimension 1–10, with one line of why)
**Experts:**
1. An Apple Design Award juror.
2. A game-UX and onboarding lead.
3. A "game feel" designer (juice, sound, haptics).
4. An iPhone Duo specialist (hinge use, book pose, the blurred half, comfort).
5. A premium mobile games publisher (pricing, store page, retention, reviews).

**Players** (see only the frames, in story order, with no docs):
6. A casual 30-year-old Duo owner.
7. A 12-year-old.
8. A puzzle player (Two Dots, Royal Match).
9. A 60-year-old grandparent.
10. A mobile games journalist doing a Duo roundup (has seen Fold Smasher, ChompDuo and Foldfish).

## Dimensions and targets
| # | Dimension | The question | Target |
|---|---|---|---|
| D1 | **Design** | Does every screen look premium, coherent and charming? Is it the best-looking Duo game? | ≥ 8.5 |
| D2 | **Ease** | Within 30 s, with no reading, do you know what to do, what's good and what's bad? | ≥ 8.5 |
| D3 | **Fun** | Is the core loop (wait, judge, snap) fun after 5 minutes? | ≥ 8.5 |
| D4 | **Satisfaction** | Does the snap feel great (look, sound, haptics in the design), and does a big bite feel like an event? | ≥ 8.5 |
| D5 | **Duo-first** | Is the hinge the star? Would it be a lesser game without a Duo? | ≥ 8.5 |
| D6 | **Willingness to pay** | Would you pay £1.99 up front on the strength of the store page and first minute? Experts: would it convert? | ≥ 8.0 (players: ≥ 7 of 10 say yes) |
| D7 | **Replay** | Would you open it again tomorrow (Daily, Bug Book, best score, ranks)? | ≥ 8.0 |
| D8 | **Store appeal** | Do the icon and the first 3 screenshots make you tap Buy? Is every caption truthful? | ≥ 8.5 |
| D9 | **Polish / bugs** | Is anything clipped, overlapping, inconsistent or confusing on any frame? | ≥ 9.0 |

**Done** means every dimension's panel median meets its target and there are no P0s. After that, the founder's
real-Duo test is the last gate.

## How a round reports
`design/SCORE-R<n>.md` contains:
- the 10 × 9 grid, with the medians;
- the delta from the last round;
- for each dimension below target, the 3 changes that would raise it most, each with an owner and a frame;
- the merged, prioritised fix list that becomes `design/ROUND-<n+1>.md`.
