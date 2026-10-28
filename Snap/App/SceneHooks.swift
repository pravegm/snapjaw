import CoreGraphics
import Foundation

/// The App's writes into the scene's R2 inputs, in one place (design/notes/scene-R2.md "New API the App must call"):
/// - `BogScene.drawnClosure`: the closure in degrees the teeth are drawn from (rest reference − the hinge's predicted
///   angle, every frame; nil on touch-only phones = the snapshot's closure);
/// - `BogScene.hudSnapsAnchor`: the HUD snaps row's leftmost live glyph, in scene space (Feast glyph flights land
///   there, a sting cracks one there, a wilt droops one there).
@MainActor
enum SceneHooks {
    static func setDrawnClosure(_ scene: BogScene?, _ degrees: Double?) {
        guard let scene else { return }
        let value = degrees.flatMap { $0.isFinite ? $0 : nil }
        if scene.drawnClosure != value { scene.drawnClosure = value }
    }

    static func setSnapsAnchor(_ scene: BogScene?, _ point: CGPoint) {
        guard let scene, point.x.isFinite, point.y.isFinite else { return }
        if scene.hudSnapsAnchor != point { scene.hudSnapsAnchor = point }
    }

    /// QA-2 #6 (Scene R4): the whole snaps row in scene space (the sting's crimson flash covers it, centred).
    static func setSnapsRow(_ scene: BogScene?, _ rect: CGRect?) {
        guard let scene else { return }
        if let r = rect, !(r.minX.isFinite && r.minY.isFinite && r.width.isFinite && r.height.isFinite) { return }
        if scene.hudSnapsRowRect != rect { scene.hudSnapsRowRect = rect }
    }

    /// QA-2 #7 (Scene R4): Home has no snaps row, so its scene shows no economy glyphs, cracks or wilts.
    static func setShowsEconomy(_ scene: BogScene?, _ on: Bool) {
        guard let scene else { return }
        if scene.showsEconomy != on { scene.showsEconomy = on }
    }

    /// R4 (REVIEW-3 #16): the Scene's 3/4 trap (`TrapArt.trapImage(style: .threeQuarter …)`, design/notes/scene-R4.md)
    /// for the isolated trap: Results, the cover, the badges. `bug`: a fly sipping on its back face. R6: in `variety`
    /// (design/notes/scene-R6.md).
    static func threeQuarterTrap(width: CGFloat, scale: CGFloat, bug: Bool,
                                 variety: TrapVariety = .classic) -> CGImage? {
        TrapArt.trapImage(style: .threeQuarter, width: width, scale: scale, sippingBug: bug ? .housefly : nil,
                          variety: variety)
    }

    /// R6 (Scene #7): the HUD's corners in scene space (the score and pause; the snaps and the chain chip), so no bug
    /// parks under them (`BogScene.hudKeepOut`; nil: the Scene's own default corners).
    static func setHUDKeepOut(_ scene: BogScene?, _ rects: [CGRect]?) {
        guard let scene else { return }
        if let rs = rects, rs.contains(where: { !($0.minX.isFinite && $0.minY.isFinite && $0.width.isFinite
                                                  && $0.height.isFinite) }) { return }
        if scene.hudKeepOut != rects { scene.hudKeepOut = rects }
    }

    /// R7 (Scene #4): Home's real button frames in scene space (`BogScene.homeButtonFrames`; nil: the Scene's own
    /// estimate). Core's resting bugs keep clear of them through `coreKeepOut`.
    static func setHomeButtonFrames(_ scene: BogScene?, _ rects: [CGRect]?) {
        guard let scene else { return }
        if let rs = rects, rs.contains(where: { !($0.minX.isFinite && $0.minY.isFinite && $0.width.isFinite
                                                  && $0.height.isFinite) }) { return }
        if scene.homeButtonFrames != rects { scene.homeButtonFrames = rects }
    }

    /// R8 (design/notes/scene-R8.md): with the hinge the inner screen never draws the lobes shut (`BogScene.usesHinge`;
    /// false: touch, the Scene plays its own shut).
    static func setUsesHinge(_ scene: BogScene?, _ on: Bool) {
        guard let scene else { return }
        if scene.usesHinge != on { scene.usesHinge = on }
    }

    /// R8 portrait (design/notes/portrait-R8.md): the App shows the scene turned a quarter clockwise on a portrait
    /// canvas, so the Scene draws its word pops turned back, upright (`BogScene.textTurned`).
    static func setTextTurned(_ scene: BogScene?, _ on: Bool) {
        guard let scene else { return }
        if scene.textTurned != on { scene.textTurned = on }
    }

    /// R6 Garden: the play trap, Home's trap and the snap glyphs in the chosen variety (`BogScene.variety`).
    static func setVariety(_ scene: BogScene?, _ v: TrapVariety) {
        guard let scene else { return }
        if scene.variety != v { scene.variety = v }
    }

    /// Where a point on the 3/4 trap's back face lands in its image drawn `width` wide and centred on `c` (y down):
    /// `u` −1…1 along the hinge, `v` 0…1 up the back lobe (`TrapPose`). Pure; tested.
    nonisolated static func threeQuarterPoint(u: CGFloat, v: CGFloat, width: CGFloat, center c: CGPoint) -> CGPoint {
        let box = TrapPose.bounds()
        let p = CGPoint(x: u * TrapPose.halfSpan, y: v * TrapPose.height).applying(TrapPose.turn)
        let k = width / max(box.width, 1)
        let h = box.height * k
        return CGPoint(x: c.x - width / 2 + (p.x - box.minX) * k, y: c.y - h / 2 + (box.maxY - p.y) * k)
    }

    /// R4 (REVIEW-3 #3): the Scene's live score and word pops, in scene space, rounded (the hint plate keeps off them).
    static func livePopRects(_ scene: BogScene?) -> [CGRect] {
        guard let scene else { return [] }
        return AppRules.roundedRects(scene.livePopRects)
    }
}
