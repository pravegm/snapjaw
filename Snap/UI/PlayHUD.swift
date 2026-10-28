import SwiftUI

/// The play layer over the scene: the HUD in the corners of the HUD page (outside the trap ellipse where it fits, so
/// it never covers bugs), the hint, the lesson card, the pause menu and the closing card. Only the buttons take
/// touches: every tap elsewhere reaches the scene (tap to snap on iPhones without a hinge).
struct PlayLayer: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDState
    let info: AppCanvas
    /// The snaps row flashes crimson on a sting (Scene R2: the scene cracks the lost glyph at the anchor).
    @State private var rowFlash = false
    @State private var flashTask: Task<Void, Never>?
    /// The chain chip bumps on each chain step (the scene no longer pops "chain ×n" on the lobe).
    @State private var chainBump = false
    @State private var bumpTask: Task<Void, Never>?
    @State private var lessonCardHeight: CGFloat = 0

    var body: some View {
        let l = HUDLayout.make(info)
        let v = hud.values
        let c = info.isCompact
        let paused = controller.isMenuOpen || controller.isClosingPaused
        let lesson = controller.route == .lesson ? controller.lessonDisplay : nil
        let showsCard = lesson.map { !$0.isFinal } ?? false
        let hintRect = showsCard ? l.lessonHint : l.hint
        ZStack {
            if let lesson, !paused, !lesson.isFinal, !v.lessonTargets.isEmpty {
                LessonPointer(targets: v.lessonTargets, info: info,
                              from: CGPoint(x: l.lesson.midX, y: l.lesson.minY + max(lessonCardHeight, 60)),
                              reduceMotion: controller.reduceMotion)
                    .allowsHitTesting(false)
            }
            if !v.lesson {
                ScoreBlock(score: v.score, best: v.best, passedBest: v.passedBest, trailing: l.trailing, compact: c)
                    .frame(width: l.score.width, height: l.score.height,
                           alignment: l.trailing ? .topTrailing : .topLeading)
                    .position(x: l.score.midX, y: l.score.midY)
                    .allowsHitTesting(false)
                if v.chainMultiplier > 1.01 {
                    ChainChip(multiplier: v.chainMultiplier, compact: c)
                        .scaleEffect(chainBump ? 1.22 : 1, anchor: l.trailing ? .trailing : .leading)
                        .frame(width: l.chain.width, height: l.chain.height,
                               alignment: l.trailing ? .trailing : .leading)
                        .position(x: l.chain.midX, y: l.chain.midY)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
                SnapsRow(left: v.snapsLeft, max: v.snapsMax, trailing: l.trailing, rows: l.snapRows,
                         hunger: v.hunger)
                    .frame(width: l.snaps.width, height: l.snaps.height,
                           alignment: l.trailing ? .trailing : .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(SnapTheme.crimson.opacity(rowFlash ? 0.55 : 0))
                            .padding(-5)
                    )
                    .position(x: l.snaps.midX, y: l.snaps.midY)
                    .allowsHitTesting(false)
            }
            if !paused {
                HintPlate(hint: v.hint, banner: v.banner, touch: controller.touchWording, compact: c)
                    .frame(width: hintRect.width, height: hintRect.height,
                           alignment: l.trailing ? .trailing : .leading)
                    .position(x: hintRect.midX, y: hintRect.midY)
                    .allowsHitTesting(false)
            }
            if let marker = controller.dailyMarker, !paused, !v.lesson {
                Text(marker.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(SnapTheme.goldLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .snapLegible()
                    .frame(width: l.score.width, alignment: l.trailing ? .trailing : .leading)
                    .position(x: l.score.midX, y: l.score.maxY + 8)
                    .allowsHitTesting(false)
            }
            if v.tired {
                // On the HUD page, never across the crease (REVIEW-1 #11).
                TiredBanner(compact: c)
                    .frame(maxWidth: l.tired.width)
                    .position(x: l.tired.midX, y: l.tired.midY)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            if let lesson, !paused {
                if lesson.isFinal {
                    LessonFinalCard(controller: controller, compact: c)
                        .frame(width: l.card.width)
                        .position(x: l.card.midX, y: info.size.height / 2)
                        .transition(.opacity)
                } else {
                    LessonCard(lesson: lesson, compact: c, onSkip: { controller.skipLesson() },
                               onHeight: { h in if abs(h - lessonCardHeight) > 1 { lessonCardHeight = h } })
                        .frame(width: l.lesson.width, height: l.lesson.height, alignment: .top)
                        .position(x: l.lesson.midX, y: l.lesson.midY)
                }
            }
            if !paused && !(lesson?.isFinal ?? false) && !v.tired {
                SnapRoundButton(systemImage: "pause.fill", label: "Pause") { controller.openMenu() }
                    .position(x: l.pause.midX, y: l.pause.midY)
            }
            if controller.isMenuOpen {
                PauseMenu(controller: controller, info: info, layout: l)
                    .transition(.opacity)
            } else if controller.isClosingPaused {
                ClosingCard(controller: controller, info: info, layout: l)
                    .transition(.opacity)
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .animation(SnapTheme.settle(controller.reduceMotion), value: controller.isMenuOpen)
        .animation(SnapTheme.settle(controller.reduceMotion), value: controller.isClosingPaused)
        .animation(SnapTheme.pop(controller.reduceMotion), value: v.chainMultiplier > 1.01)
        .animation(SnapTheme.pop(controller.reduceMotion), value: v.tired)
        .onAppear { reportAnchor(l, slots: SnapsRow.slots(left: v.snapsLeft, max: v.snapsMax)) }
        .onChange(of: info) { _, _ in
            reportAnchor(HUDLayout.make(info), slots: SnapsRow.slots(left: hud.values.snapsLeft,
                                                                      max: hud.values.snapsMax))
        }
        .onChange(of: SnapsRow.slots(left: v.snapsLeft, max: v.snapsMax)) { _, slots in
            reportAnchor(HUDLayout.make(info), slots: slots)
        }
        .onChange(of: v.stings) { old, new in
            guard new > old else { return }
            flashRow()
        }
        .onChange(of: v.chainMultiplier) { old, new in
            guard new > old + 0.01 else { return }
            bumpChain()
        }
        .onDisappear {
            flashTask?.cancel()
            bumpTask?.cancel()
        }
    }

    /// The Scene's economy glyphs (Feast flights, the sting crack, the wilt droop) land on the row's first glyph.
    private func reportAnchor(_ l: HUDLayout, slots: Int) {
        controller.setSnapsAnchor(info.scenePoint(l.firstGlyphCenter(slots: slots)))
    }

    /// A sting: the snaps row flashes crimson for a beat.
    private func flashRow() {
        withAnimation(.easeOut(duration: 0.08)) { rowFlash = true }
        flashTask?.cancel()
        flashTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 380_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { rowFlash = false }
        }
    }

    /// A chain step: the chip bumps.
    private func bumpChain() {
        guard !controller.reduceMotion else { return }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { chainBump = true }
        bumpTask?.cancel()
        bumpTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { chainBump = false }
        }
    }
}

/// The lesson's pointer (REVIEW-1 #9): a pulsing ring round each bug in play (lime for a fly, white for a bee: wait)
/// and an arrow from the lesson card to each. Still in demo captures and under Reduce Motion.
struct LessonPointer: View {
    let targets: [LessonTarget]
    let info: AppCanvas
    /// The bottom centre of the lesson card (screen).
    let from: CGPoint
    var reduceMotion = false

    static let period: Double = 1.1

    var body: some View {
        let still = reduceMotion || AppTrace.enabled
        let bounds = CGRect(origin: .zero, size: info.size).insetBy(dx: -20, dy: -20)
        let all: [(CGPoint, Bool)] = targets.map { t in (info.screenPoint(t.point), t.bee) }
        let points = all.filter { bounds.contains($0.0) }
        let ringR = max(28, 46 * info.scale)
        let origin = from
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let t = still ? 0.25 : context.date.timeIntervalSinceReferenceDate
            let pulse = CGFloat((sin(t * 2 * Double.pi / Self.period) + 1) / 2)
            Canvas { g, _ in
                for (p, bee) in points {
                    let color = bee ? Color.white : SnapTheme.limeLight
                    let r = ringR + 6 * pulse
                    let ring = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                    g.stroke(ring, with: .color(Color.black.opacity(0.35)), lineWidth: 6)
                    g.stroke(ring, with: .color(color.opacity(0.6 + 0.4 * Double(pulse))),
                             style: StrokeStyle(lineWidth: 3.5, dash: bee ? [8, 6] : []))
                    // The arrow: from the card toward the ring, stopping short of it.
                    let dx = p.x - origin.x
                    let dy = p.y - origin.y
                    let len = (dx * dx + dy * dy).squareRoot()
                    guard len > r + 40 else { continue }
                    let ux = dx / len
                    let uy = dy / len
                    let start = CGPoint(x: origin.x + ux * 10, y: origin.y + uy * 10)
                    let tip = CGPoint(x: p.x - ux * (r + 6), y: p.y - uy * (r + 6))
                    var shaft = Path()
                    shaft.move(to: start)
                    shaft.addLine(to: tip)
                    g.stroke(shaft, with: .color(Color.black.opacity(0.3)),
                             style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    g.stroke(shaft, with: .color(color.opacity(0.85)),
                             style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10, 7]))
                    var head = Path()
                    let w: CGFloat = 9
                    head.move(to: CGPoint(x: tip.x + ux * 4, y: tip.y + uy * 4))
                    head.addLine(to: CGPoint(x: tip.x - ux * 12 - uy * w, y: tip.y - uy * 12 + ux * w))
                    head.addLine(to: CGPoint(x: tip.x - ux * 12 + uy * w, y: tip.y - uy * 12 - ux * w))
                    head.closeSubpath()
                    g.fill(head, with: .color(color))
                }
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .accessibilityHidden(true)
    }
}


// MARK: - HUD pieces

/// The protein total (big, rounded heavy) and the best under it.
struct ScoreBlock: View {
    let score: Int
    let best: Int
    let passedBest: Bool
    let trailing: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            Text(AppRules.formatted(score))
                .font(SnapType.number(compact ? 36 : 44))
                .foregroundStyle(SnapTheme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(score)))
                .animation(.easeOut(duration: 0.25), value: score)
                .snapLegible()
            Text(passedBest ? "NEW BEST" : (best > 0 ? "BEST " + AppRules.formatted(best) : "PROTEIN"))
                .font(.system(size: compact ? 11 : 13, weight: .heavy, design: .rounded))
                .kerning(0.8)
                .foregroundStyle(passedBest ? SnapTheme.gold : SnapTheme.mist)
                .snapLegible()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Protein \(score)" + (best > 0 ? ", best \(best)" : ""))
    }
}

/// The chain multiplier chip ("Chain ×2"). Sized by its content (`.fixedSize()`, REVIEW-1 #2): never "Chain…".
struct ChainChip: View {
    let multiplier: Double
    let compact: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: compact ? 12 : 14, weight: .heavy))
            Text("Chain " + AppRules.multiplierText(multiplier))
                .font(.system(size: compact ? 14 : 17, weight: .heavy, design: .rounded).monospacedDigit())
                .lineLimit(1)
        }
        .foregroundStyle(SnapTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(LinearGradient(colors: [SnapTheme.goldLight, SnapTheme.gold], startPoint: .top,
                                                  endPoint: .bottom)))
        .overlay(Capsule().stroke(SnapTheme.goldDeep, lineWidth: 1.5))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// The snaps as little trap icons (up to 12): filled for each snap left, hollow up to the start. The next snap to go
/// (the last filled one) drains with hunger (GAME-DESIGN §5 "Hunger"): its fill sinks and greys as a wilt nears.
/// The numeral has a fixed box (REVIEW-1 #3: "12" never clips); 11–12 slots use the small glyph; a short phone wraps
/// the row into two rows of six.
struct SnapsRow: View {
    let left: Int
    let max: Int
    let trailing: Bool
    var rows: Int = 1
    /// 0 just fed … 1 a snap wilts.
    var hunger: Double = 0

    static func slots(left: Int, max: Int) -> Int {
        Swift.min(Swift.max(Swift.max(left, Tuning.startSnaps), 0), Swift.max(max, 1))
    }

    var body: some View {
        let count = Self.slots(left: left, max: max)
        let icon = rows > 1 ? HUDLayout.snapIconSmall : HUDLayout.glyphSize(slots: count)
        let perRow = rows > 1 ? (count + 1) / 2 : count
        let drain = Swift.min(Swift.max(hunger.isFinite ? hunger : 0, 0), 1)
        HStack(spacing: 4) {
            if trailing { Spacer(minLength: 0) }
            Text("\(Swift.max(left, 0))")
                .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(left <= 1 ? SnapTheme.danger : SnapTheme.cream)
                .lineLimit(1)
                .fixedSize()
                .snapLegible()
                .frame(width: HUDLayout.snapNumeralW, alignment: trailing ? .trailing : .leading)
            VStack(alignment: trailing ? .trailing : .leading, spacing: 6) {
                ForEach(0..<Swift.max(rows, 1), id: \.self) { r in
                    HStack(spacing: HUDLayout.snapGap) {
                        ForEach(Swift.min(r * perRow, count)..<Swift.min((r + 1) * perRow, count), id: \.self) { i in
                            SnapSlot(filled: i < left, drain: i == left - 1 ? drain : 0, size: icon)
                        }
                    }
                }
            }
            if !trailing { Spacer(minLength: 0) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Swift.max(left, 0)) snaps left" + (drain > 0.75 ? ", hungry" : ""))
    }
}

/// One snap glyph: filled (crimson), spent (dark), or draining (`drain` 0…1 of its fill gone, greyed).
struct SnapSlot: View {
    let filled: Bool
    var drain: Double = 0
    let size: CGFloat

    var body: some View {
        let h = size * 0.82
        let left = CGFloat(1 - Swift.min(Swift.max(drain, 0), 1))
        ZStack {
            SnapGlyph().fill(Color.black.opacity(0.35))
            if filled {
                SnapGlyph()
                    .fill(LinearGradient(colors: [SnapTheme.pink, SnapTheme.crimson], startPoint: .top,
                                         endPoint: .bottom))
                    .saturation(1 - drain * 0.85)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: h * left)
                    }
            }
            SnapGlyph().stroke(filled ? (drain > 0.75 ? SnapTheme.pink : SnapTheme.lime)
                                      : SnapTheme.haze.opacity(0.6), lineWidth: 1.5)
        }
        .frame(width: size, height: h)
    }
}

/// The hint (or the run-start line): up to two short lines on a cream plate (warnings on crimson).
struct HintPlate: View {
    let hint: TrapHint?
    let banner: String?
    let touch: Bool
    let compact: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
        ZStack {
            if let hint, let text = AppRules.hintText(hint, touch: touch) {
                let warn = AppRules.hintIsWarning(hint)
                Text(text)
                    .font(SnapType.hint(compact))
                    .foregroundStyle(warn ? SnapTheme.cream : SnapTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(shape.fill(warn ? SnapTheme.crimson : SnapTheme.cream))
                    .overlay(shape.stroke(warn ? SnapTheme.pink : SnapTheme.lime, lineWidth: 2))
                    .shadow(color: SnapTheme.shadow.opacity(0.5), radius: 8, y: 3)
                    .id(text)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .accessibilityLabel(text)
            } else if let banner {
                Text(banner)
                    .font(SnapType.headline(compact))
                    .foregroundStyle(SnapTheme.cream)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(shape.fill(SnapTheme.surface.opacity(0.85)))
                    .overlay(shape.stroke(SnapTheme.lime.opacity(0.4), lineWidth: 1.5))
                    .id(banner)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: hint)
        .animation(.easeOut(duration: 0.25), value: banner)
    }
}

/// "Your trap is tired." (the run's end, before Results).
struct TiredBanner: View {
    let compact: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("Your trap is tired.")
                .font(SnapType.title(compact))
                .foregroundStyle(SnapTheme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Out of snaps")
                .font(SnapType.caption(compact))
                .foregroundStyle(SnapTheme.mist)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Capsule().fill(SnapTheme.surface.opacity(0.92)))
        .overlay(Capsule().stroke(SnapTheme.lime.opacity(0.4), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pause and closing

/// The pause menu: Resume, Restart, Home, on a card on the HUD page (the sharp, reachable half).
struct PauseMenu: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas
    let layout: HUDLayout

    var body: some View {
        let c = info.isCompact
        let other = info.otherPage
        ZStack {
            Color.black.opacity(0.55)
                .contentShape(Rectangle())
                .onTapGesture {}
            Text("The bugs will wait.")
                .font(SnapType.title(c))
                .foregroundStyle(SnapTheme.cream)
                .snapLegible()
                .multilineTextAlignment(.center)
                .frame(width: min(other.width, 360))
                .position(x: other.midX, y: info.size.height / 2)
                .accessibilityHidden(true)
            VStack(spacing: c ? 8 : 12) {
                SnapOverline(text: "Paused", compact: c, color: SnapTheme.gold)
                SnapButton(kind: .primary, height: c ? 56 : SnapTheme.primaryHeight, compact: c,
                           action: { controller.resume() }) {
                    Text("Resume")
                }
                SnapButton(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c,
                           action: { controller.restart() }) {
                    Text(controller.restartLabel)
                }
                SnapButton(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c,
                           action: { controller.goHome() }) {
                    Text("Home")
                }
                if controller.isScoredDaily {
                    Text("Leaving keeps today's protein so far.")
                        .font(SnapType.caption(c))
                        .foregroundStyle(SnapTheme.mist)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: min(layout.card.width - 36, 340))
            .snapCard(padding: c ? 14 : 18, radius: 26)
            .position(x: layout.card.midX, y: info.size.height / 2)
        }
    }
}

/// The closing pause: "Open it up to carry on" (θ under 50° for 0.6 s). Nothing steps until it's open again (past
/// 120°: the pause lifts from the hinge reports, QA-1 #1).
struct ClosingCard: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas
    let layout: HUDLayout

    /// One line for "open to carry on" everywhere (the cover card says it too: REVIEW-1-ux P2 #14).
    static let title = CoverCard.carryOn
    static let detail = "The bugs are waiting. So is your trap."

    var body: some View {
        let c = info.isCompact
        ZStack {
            Color.black.opacity(0.5)
                .contentShape(Rectangle())
                .onTapGesture {}
            VStack(spacing: c ? 10 : 14) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: c ? 30 : 38, weight: .heavy))
                    .foregroundStyle(SnapTheme.limeLight)
                    .accessibilityHidden(true)
                Text(Self.title)
                    .font(SnapType.title(c))
                    .foregroundStyle(SnapTheme.cream)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.detail)
                    .font(SnapType.body(c))
                    .foregroundStyle(SnapTheme.mist)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                SnapButton(kind: .quiet, height: SnapTheme.minTap, compact: c, action: { controller.openMenu() }) {
                    Text("Menu")
                }
            }
            .frame(width: min(layout.card.width - 36, 340))
            .snapCard(padding: c ? 14 : 20, radius: 26)
            .position(x: layout.card.midX, y: info.size.height / 2)
            .accessibilityElement(children: .contain)
        }
    }
}

// MARK: - The First Bite lesson

/// One sentence per step, the step number, praise (green-gold) or a warning (crimson), and Skip on every step. Only
/// Skip takes touches (QA-1 #11): a tap anywhere else on the card reaches the scene (tap to snap on phones).
struct LessonCard: View {
    let lesson: LessonDisplay
    let compact: Bool
    let onSkip: () -> Void
    var onHeight: (CGFloat) -> Void = { _ in }

    var body: some View {
        let pad: CGFloat = compact ? 10 : 14
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack {
                SnapOverline(text: "First Bite · " + lesson.stepOf, compact: compact)
                Spacer(minLength: 6)
                // Room for the Skip button (drawn over the card, the one hit-testable part).
                Color.clear.frame(width: lesson.allowsSkip ? SnapTheme.minTap : 0, height: 30)
            }
            Text(lesson.line)
                .font(SnapType.headline(compact))
                .foregroundStyle(SnapTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
            if let praise = lesson.praise {
                Text(praise)
                    .font(SnapType.hint(compact))
                    .foregroundStyle(SnapTheme.gold)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if let warning = lesson.warning {
                Text(warning)
                    .font(SnapType.body(compact))
                    .foregroundStyle(SnapTheme.pink)
                    .transition(.opacity)
            }
        }
        .snapCard(padding: pad, radius: 20)
        .background(GeometryReader { g in
            Color.clear.preference(key: LessonCardHeightKey.self, value: g.size.height)
        })
        .onPreferenceChange(LessonCardHeightKey.self) { h in onHeight(h) }
        .animation(.easeOut(duration: 0.2), value: lesson)
        .allowsHitTesting(false)
        .overlay(alignment: .topTrailing) {
            if lesson.allowsSkip {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(SnapType.body(compact))
                        .foregroundStyle(SnapTheme.mist)
                        .frame(minWidth: SnapTheme.minTap, minHeight: SnapTheme.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, pad - 14)
                .padding(.trailing, pad - 6)
                .accessibilityHint("Skip the lesson")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct LessonCardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The lesson's last card: "Snaps run out. Big bites earn them back." Then Feed.
struct LessonFinalCard: View {
    @ObservedObject var controller: GameController
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            SnapOverline(text: "First Bite done", compact: compact, color: SnapTheme.gold)
            Text(LessonScript.line(.done, touch: controller.touchWording))
                .font(SnapType.title(compact))
                .foregroundStyle(SnapTheme.cream)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Every snap costs one. Three bugs in one bite give one back. Bees cost one more. "
                 + "Wait too long and a snap wilts.")
                .font(SnapType.body(compact))
                .foregroundStyle(SnapTheme.mist)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            SnapButton(kind: .primary, height: compact ? 56 : SnapTheme.primaryHeight, compact: compact,
                       action: { controller.finishLesson() }) {
                Text("Start feeding")
            }
            SnapButton(kind: .quiet, height: SnapTheme.minTap, compact: compact,
                       action: { controller.finishLessonHome() }) {
                Text("Home")
            }
        }
        .snapCard(padding: compact ? 16 : 22, radius: 28)
    }
}
