# Portrait R8: the laptop pose plays (no pose card)

Founder rule (ROUND-8 §1b): "no pose demands, ever: flat, laptop, any angle plays". Until now a Duo held in portrait
(laptop/tabletop: the fold across the middle, the halves top and bottom) showed a `PoseCard`. That card is gone: portrait
plays. Owner: App and Scene. **Not compiled locally**: CI compiles.

## New and changed APIs and log lines (read these first)

**App rules (`Snap/App/AppRules.swift`, pure, tested)**
- `AppRules.pose(canvas:hingeSeen:isShut:)` never returns a pose card: `AppPose` is now `{ play, cover }` (`.pose` is
  deleted). Portrait is `.play`.
- `AppRules.turnsScene(_ canvas:)`: a portrait canvas (height > width) shows the landscape scene turned a quarter
  clockwise. `AppRules.sceneViewSize(_:)`: the scene view's own (landscape) size.
- `AppRules.hasFold`: no longer false for portrait (the laptop fold lies along the turned scene's midrib).
- `AppRules.hudOnLeft(_ setting:, canvas:)`: "Score on the left" is a book-pose setting; a turned scene keeps its HUD on
  the scene's right lobe (the bottom page). GameController (`layoutHudOnLeft`) and RootView both use it.
- `AppRules.demoTurnsCanvas(_:demoPortrait:)` (CI, below).

**Canvas (`AppCanvas`, `Snap/UI/Layout.swift`)**
- `rotated` (= `turnsScene(size)`), `sceneViewSize`. `scale`, `screenX`, `screenPoint`, `scenePoint`, `screenRect`,
  `trapRect`, `trapOutline` all map through the quarter turn: the view point (x, y) lands at (view height − y, x).
  Scene right is screen down; scene up is screen right; the scene's right lobe is the bottom half.
- `foldBand` (a column in book pose, a row across the middle in portrait), `foldMinY` / `foldMaxY`; `foldMinX/MaxX` are
  `foldBand`'s (unchanged in book pose). `isFoldClear` checks y in portrait.
- `leftPage` / `rightPage` in portrait are the **top** and **bottom** pages (full width less the margins, to the fold's
  clear band). `hudPage` is the bottom page, `otherPage` the top one. `hudHalf`, `otherHalf`, `towardHUD` (the menus'
  shades), `columnTop(_:back:)`, `headerPads(_:back:)` (back-button clearance, generic for both poses).
- `isCompact` is now the short side < 520 (book pose unchanged; a portrait phone stays compact). `thumbZones` in portrait:
  the bottom half's sides.

**HUD (`HUDLayout`)**: `make` dispatches portrait canvases to `portrait(…)`. New fields `snapsTrailing`, `chainTrailing`,
`columns` (book pose: all equal to `trailing` / 7, so nothing moves). `rowsWidth(glyph:columns:)` (defaulted),
`portraitScoreMin` 64, `portraitColumns` [7, 5]. `glyphCenter` uses `columns` and `snapsTrailing`.

**RootView**: no `PoseCard`, no `phoneCardReady`/`phoneCardDelay`. `gameLayer` frames the SpriteView at
`sceneViewSize` and turns it `rotationEffect(90°)` in portrait (0° otherwise: the same view, so a rotation never rebuilds
it). A phone held upright still asks iOS to turn (`requestLandscape`) and plays turned meanwhile. `turnedInsets(_:)`.

**GameController**: `canvasTurned`, `demoPortrait`; `updateCanvas` sets `SceneHooks.setTextTurned` (before its
same-layout early return: rotating a Duo keeps the layout). The `.pose` pause reason now only means the cover.

**Scene (`Snap/Scene`, minimal)**: `BogScene.textTurned` (App sets it via `SceneHooks.setTextTurned`): every word pop is
drawn a quarter turn counter-clockwise (upright on the turned screen), rises toward scene −x (the screen's top), and is
placed by its turned box (`placePop`: the length limit runs up the trap's height, the rise clamp is in x, the dodge
offsets turn). `BogPops.quarterTurn`, `labelAngle`, `riseDirection`, `shadowOffset`, `drawnBox`;
`BogScene.popFootprint(…, turned:)` (defaulted). `activeRects` / `liveRects` (the App's plate keep-out) are the turned
boxes. Book pose and phones: identical numbers.

**Deleted**: `PoseCard`, `PoseCardLayout`, `PoseDiagram`, `PoseDiagramArt` (PoseCards.swift keeps only the cover
cards), `DuoClapDiagram` (TrapDrawing; its last user), `HomeView.foldDiagramHeight`, and their tests
(`poseCardFits`, the clap and pose-diagram checks).

**Log line**: `SNAP-T canvas <w>x<h> fold=<0|1> hudLeft=<0|1>` gains ` turned=1` on a portrait canvas (only then, so
every existing grep still matches).

## The portrait layout (669 × 951, fold y ≈ 455–496)
The trap fills the canvas (941 of 951 tall, 643 of 669 wide), so the only room off the cilia is the four corners, each a
narrow strip up a side edge (about 75–115 pt wide at the very bottom, under 40 pt 100 pt up). Measured with a Node port of
`trapOutline` before writing the Swift.
- **Bottom page = HUD page** (the scene's right lobe, as in book pose). In laptop pose the hand closes the top half by its
  top edge, so the bottom corners stay uncovered.
  - Score: the bottom-right corner (≥ 64 pt wide, the number scales), Pause over it.
  - Snaps: the bottom-left corner, rows of 7 or 5 (whichever gives the bigger glyph with a labelled numeral; ~19 pt with
    no insets, 13 pt with a 24/20 pt cut-out), "14 / SNAPS" over them.
  - Chain chip: the top-right corner ("×2"; "Chain ×2" when there is room).
  - Level goal: the score's mirror through the centre (top-left).
  - Hint: just under the fold, the score's side; the alternate slot on the snaps' side. Tired banner and pause card:
    the bottom page.
- **Menus**: every view now positions on its page (`page.midY`, `page.height`) instead of the canvas's middle, so book
  pose is unchanged and portrait stacks top/bottom. Back is top-left (headers and columns keep clear of it). Results drops
  its trap picture in portrait (the top page is ~430 pt). Home: the title on top, Play and the pads below.

## Tests
- AppTests `PortraitTests`: `aPortraitDuoNeverShowsAPoseCard` (pose, turn, fold, HUD side, same scene layout),
  `portraitDemoKeys` (DEBUG), `theTurnMapsTheSceneOntoTheScreen` (centre, corners, directions, full cover, inverse, fold
  band, trap, pages; book pose untouched), `thePortraitHUDIsUprightOffTheFoldAndClearOfTheCilia` (both inset cases, both
  sides: cilia ≥ 8 pt, fold-clear, corners, glyph rows, every hint line fits, goal on top), `menusLayOutOnTheTopAndBottomPages`
  (back, headers, columns, pages; book pose's 64 pt paddings kept).
- Updated: `poses`, `fold` (portrait plays, has the fold). Removed: `poseCardFits`, the DuoClap/PoseDiagram checks.
- SceneTests `ScenePortraitTests`: turned pops are upright, tall in scene space, rise toward −x, the live footprint and
  `popFootprint(turned:)` follow; `textTurned` / `SceneHooks.setTextTurned`.

## CI (demo keys and scenarios)
- **`portrait=1`** (any screen, any other key) and **`screen=pose`** (now = `portrait=1` over Home, or a run of `mode`):
  the simulator has no rotate verb, so RootView lays the app out at the turned canvas (669 × 951 on the Duo) and turns
  the whole picture a quarter counter-clockwise onto the landscape panel. **Turn those PNGs a quarter clockwise**
  (`sips -r 90`) to read them. On the Duo the scene inside is net unturned, its midrib on the sim's real fold.
- `ci/duo-scenarios.txt`: 17-pose re-captioned (it is now the portrait Home; duo.sh's `frames-pose` launch, which uses
  `screen=pose`, frames it too); new **32-portrait-home, 33-portrait-crowd, 34-portrait-feast, 35-portrait-results,
  36-portrait-levels** (expect `turned=1` or the freeze/event line).
- `ci/scenarios.txt` 31-pose: `screen=pose;fold=1` (the phone's 402 × 874 portrait layout, turned).
- `ci/duo-store-scenarios.txt` DR4-pose: re-captioned; its `turned=1` canvas fails REQUIRE_LOG by design (review only).

## For other owners (not edited: not my files)
- **ci/duo.sh** (Core/CI): the `frames-pose` comment ("The pose card…") and `POSE-CARD` INFO now describe the portrait
  frame; rename to PORTRAIT when convenient. **ci/README.md** still lists "the pose card".
- **Store copy**: D01's caption "Hold it open like a book." reads as a pose demand next to this rule; the founder may
  want "Open it like a book" or similar.

## Unsure / for review (CI and the founder's hands)
- SwiftUI `rotationEffect` on a `SpriteView`: drawing is certain; touch is only used on phones (landscape), but UIKit
  maps touches through view transforms, so a tap on a turned Duo scene should land right.
- The real Duo's portrait safe-area insets are a guess (tested at none and 24/20 pt).
- Turned pops: lines "under" a callout are still placed by scene −y, so they may sit beside it rather than below; the
  turned footprints keep them from overlapping.
- The scene's own glyph flights (snaps won) are drawn in scene space, so their little traps arrive turned a quarter.
- Which half iOS blurs when a fold starts from flat in portrait is unknown; "Score on the left" does nothing in portrait.
