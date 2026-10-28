# Icon R4: the game's fly, smaller, and both lobes' crimson (REVIEW-3 #17)

I changed only `Snap/UI/AppIconArt.swift`. `AppIconArt` and `AppIconPainter.paint(_:)` keep their signatures.
`screen=icon` renders it on CI.

**Kept:** the composition the panel liked. That is the 3/4 trap tilted −0.2 rad, the glossy crimson back lobe with
its gloss crescent, the crown of 13 pale cilia, the green front lobe, the stem bottom-left, and the bog background. A
fly peeks over the rim with its hands on the lip.

**Changed:**
- **The fly is the in-game housefly** (`TrapArt.bugStyle(.housefly)`).
  - The thorax is grey-blue (#9AA5B5 → #575E6B → #2E323A) and the head is darker (#3F444E).
  - It has cream eyes (#FFF6F0) with dark pupils (#1A0E10) that look up at the jaw, and soft pink cheeks.
  - Its glassy wings run white → #DDEBFF, at 60 % opacity, each with a faint vein and a glint.
  - A dark halo behind it separates the grey from the crimson.
  - It is drawn in the trap frame, so it tilts with the trap.
- **About 35 % of the trap's width.** The fly measures ±112 units wings included, against a 640-unit trap. It used
  to be over 70 %, with a body alone of 330 units.
- **Both lobes' crimson edges.**
  - The back lobe's face runs up to its margin, as before.
  - The front lobe now shows its own inner face as a crimson band just inside the lip (`frontInner` → `frontRim`).
    The band runs #7E0E2A at the hinge to #E04A62 at the margin, with a wet streak.
  - The band covers the fly's lower head, so the fly is visibly inside.
- **Cilia frame the mouth.** A shorter fringe of 8 cilia hangs off the front lip, fanning out to the sides. The middle
  under the fly is left bare, so nothing reads as teeth. Every cilium points away from the mouth.

**Rules checked:**
- There are no outlines. The wing vein is a 3-unit translucent line inside the wing, not an edge.
- The canvas is opaque and full-bleed.
- The trap, cilia and fly stay inside x 148–876 and y 211–820 of 1024, so they clear the outer 10 % (102 units).
  Only the background and the stem reach the edges, as in R3.

**Small sizes:** I checked a canvas port of the same geometry at 180, 60 and 29 px.
- At 60 px it reads as a red trap with a pale crown and fringe, and a grey fly with two white eyes and wings.
- At 29 px it reads as a red cup with a crown and a small grey-and-white bug inside. Shrinking the fly makes it less
  legible at 29 px. That is the trade #17 asked for.

**Open point:** ROUND-4 says "red eyes", but the in-game housefly has cream eyes with dark pupils. Red eyes belong to
the fruit fly (#FF8A7A → #C8283E). I matched the game, so the icon and the game agree. If red eyes are still wanted,
change `flyEye` to `0xC8283E`; the pupils and glints stay as they are.
