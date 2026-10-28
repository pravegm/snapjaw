import SwiftUI
import UIKit

/// The play layer over the scene: the HUD in the outer corners of the HUD page (R3: off the cilia, `HUDLayout`), the
/// hint, the lesson card, the pause menu and the closing card. Only the buttons take touches: every tap elsewhere
/// reaches the scene (tap to snap on iPhones without a hinge).
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
        let inner: HorizontalAlignment = l.trailing ? .leading : .trailing
        let hintAlign = Alignment(horizontal: inner, vertical: showsCard ? .bottom : .top)
        let showsSnaps = !v.lesson || v.lessonSnaps
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
                    ChainChip(multiplier: v.chainMultiplier, compact: c, short: l.chainCompact)
                        .scaleEffect(chainBump ? 1.22 : 1, anchor: l.trailing ? .trailing : .leading)
                        .frame(width: l.chain.width, height: l.chain.height,
                               alignment: l.trailing ? .trailing : .leading)
                        .position(x: l.chain.midX, y: l.chain.midY)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            if showsSnaps {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SnapTheme.crimson.opacity(rowFlash ? 0.55 : (v.rowFlashing ? 0.4 : 0)))
                    .animation(.easeOut(duration: 0.12), value: v.rowFlashing)
                    .frame(width: l.snaps.width + 12, height: l.snaps.height + 12)
                    .position(x: l.snaps.midX, y: l.snaps.midY)
                    .allowsHitTesting(false)
                SnapsRow(left: v.snapsLeft, layout: l, size: info.size, hunger: v.hunger, hungry: v.hungry,
                         reduceMotion: controller.reduceMotion)
                    .allowsHitTesting(false)
                if v.ringSnaps && !paused {
                    SnapsRing(rect: l.snaps, reduceMotion: controller.reduceMotion)
                        .allowsHitTesting(false)
                }
                if let gain = v.snapGain {
                    SnapGainTag(text: gain, compact: c)
                        .position(x: l.chain.midX, y: l.chain.minY - (c ? 14 : 18))
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            if !paused {
                HintPlate(hint: v.hint, banner: v.banner, touch: controller.hintTouch, compact: c)
                    .frame(width: hintRect.width, height: hintRect.height, alignment: hintAlign)
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
                    .position(x: l.score.midX, y: l.score.maxY + 6)
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
                    LessonFinalCard(controller: controller, compact: c, trailing: l.trailing)
                        .frame(width: l.card.width)
                        .position(x: l.card.midX, y: min(info.size.height / 2, (l.card.minY + l.chain.minY) / 2))
                        .transition(.opacity)
                } else {
                    LessonCard(lesson: lesson, compact: c, reduceMotion: controller.reduceMotion,
                               onSkip: { controller.skipLesson() },
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
        .animation(SnapTheme.pop(controller.reduceMotion), value: v.snapGain)
        .onAppear { reportAnchor(l, left: v.snapsLeft) }
        .onChange(of: info) { _, _ in
            reportAnchor(HUDLayout.make(info), left: hud.values.snapsLeft)
        }
        .onChange(of: v.snapsLeft) { _, left in
            reportAnchor(HUDLayout.make(info), left: left)
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

    /// The Scene's economy glyphs (Feast flights, the sting crack, the wilt droop) land on the row's live edge.
    private func reportAnchor(_ l: HUDLayout, left: Int) {
        controller.setSnapsAnchor(info.scenePoint(l.anchor(snapsLeft: left)))
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
                .font(SnapType.number(compact ? 32 : 40))
                .foregroundStyle(SnapTheme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(score)))
                .animation(.easeOut(duration: 0.25), value: score)
                .snapLegible()
            Text(passedBest ? "NEW BEST" : (best > 0 ? "BEST " + AppRules.formatted(best) : "PROTEIN"))
                .font(.system(size: compact ? 11 : 12, weight: .heavy, design: .rounded))
                .kerning(0.8)
                .foregroundStyle(passedBest ? SnapTheme.gold : SnapTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .snapLegible()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Protein \(score)" + (best > 0 ? ", best \(best)" : ""))
    }
}

/// The chain multiplier chip ("Chain ×2"; `short`: "×2" with the link, where the cilia leave less room). Sized by its
/// content (`.fixedSize()`, REVIEW-1 #2).
struct ChainChip: View {
    let multiplier: Double
    let compact: Bool
    var short = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: compact ? 12 : 14, weight: .heavy))
            Text((short ? "" : "Chain ") + AppRules.multiplierText(multiplier))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chain " + AppRules.multiplierText(multiplier))
    }
}

/// The snaps: every snap the trap can hold (`Tuning.maxSnaps` 14) as mini closed traps in two rows of seven, filled
/// for each snap left, a grey outline for each empty slot (REVIEW-2 #11). The next snap to go (the last full one)
/// drains with hunger and, 3 s before it wilts, pulses crimson while the numeral ticks red. The numeral sits on the
/// inner side of the lower row. Drawn at the layout's absolute positions over the whole canvas.
struct SnapsRow: View {
    let left: Int
    let layout: HUDLayout
    let size: CGSize
    /// 0 just fed … 1 a snap wilts.
    var hunger: Double = 0
    var hungry = false
    var reduceMotion = false

    /// The hungry pulse: 1.6 Hz.
    static let pulseHz: Double = 1.6

    /// The numeral's tick: a bump at the start of every second, fading over a quarter of it. Pure; tested.
    static func tick(at t: Double) -> Double {
        guard t.isFinite else { return 1 }
        let f = t - t.rounded(.down)
        return 1 + 0.28 * max(0, 1 - f / 0.25)
    }

    var body: some View {
        let count = HUDLayout.slotCount
        let drain = Swift.min(Swift.max(hunger.isFinite ? hunger : 0, 0), 1)
        let still = reduceMotion || AppTrace.enabled
        let shown = Swift.max(left, 0)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still || !hungry)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = hungry ? (still ? 1 : (sin(t * 2 * Double.pi * Self.pulseHz) + 1) / 2) : 0
            let bump = hungry && !still ? Self.tick(at: t) : 1
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    SnapSlot(filled: i < shown, drain: i == shown - 1 ? drain : 0, hot: i == shown - 1 ? pulse : 0,
                             size: layout.glyph)
                        .position(layout.glyphCenter(i))
                }
                Text("\(shown)")
                    .font(.system(size: layout.glyph > 18 ? 17 : 15, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(shown <= 1 || hungry ? SnapTheme.danger : SnapTheme.cream)
                    .lineLimit(1)
                    .fixedSize()
                    .scaleEffect(bump)
                    .snapLegible()
                    .frame(width: layout.numeral.width, height: layout.numeral.height,
                           alignment: layout.trailing ? .trailing : .leading)
                    .position(x: layout.numeral.midX, y: layout.numeral.midY)
            }
            .frame(width: size.width, height: size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shown) snaps left" + (hungry ? ", hungry" : ""))
    }
}

/// The lesson's last card rings the snaps row ("These are your snaps", REVIEW-2 #12).
struct SnapsRing: View {
    let rect: CGRect
    var reduceMotion = false

    var body: some View {
        let still = reduceMotion || AppTrace.enabled
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let t = still ? 0.25 : context.date.timeIntervalSinceReferenceDate
            let pulse = CGFloat((sin(t * 2 * Double.pi / LessonPointer.period) + 1) / 2)
            let r = rect.insetBy(dx: -10 - 4 * pulse, dy: -10 - 4 * pulse)
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.35), lineWidth: 6)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SnapTheme.limeLight.opacity(0.6 + 0.4 * Double(pulse)), lineWidth: 3.5)
            }
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
        }
        .accessibilityHidden(true)
    }
}

/// The first Feast's one-time label over the snaps ("+1 snap", REVIEW-2 #12).
struct SnapGainTag: View {
    let text: String
    let compact: Bool

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 15 : 18, weight: .black, design: .rounded))
            .foregroundStyle(SnapTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(SnapTheme.limeLight))
            .overlay(Capsule().stroke(SnapTheme.lime, lineWidth: 1.5))
            .fixedSize()
            .shadow(color: SnapTheme.shadow.opacity(0.5), radius: 6, y: 2)
    }
}

/// The hint (or the run-start line): up to three short lines on a cream plate (warnings on crimson). REVIEW-2 #3:
/// never truncated (`HintFit`, tested for every line at both plate widths).
struct HintPlate: View {
    let hint: HUDHint?
    let banner: String?
    let touch: Bool
    let compact: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
        ZStack {
            if let hint, let text = AppRules.hudHintText(hint, touch: touch) {
                let warn = AppRules.hudHintIsWarning(hint)
                Text(text)
                    .font(SnapType.hint(compact))
                    .foregroundStyle(warn ? SnapTheme.cream : SnapTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(HintFit.maxLines)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, HintFit.horizontalPadding)
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
                    .lineLimit(HintFit.maxLines)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, HintFit.horizontalPadding)
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

/// Measures a hint line as the plate sets it (SnapType.hint: SF Rounded Heavy 19 / 23 pt), so a test can prove no
/// line is ever cut (REVIEW-2 #3: "Last snap — make i…").
enum HintFit {
    static let maxLines = 3
    static let horizontalPadding: CGFloat = 12

    static func font(compact: Bool) -> UIFont {
        let size: CGFloat = compact ? 19 : 23
        let base = UIFont.systemFont(ofSize: size, weight: .heavy)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: rounded, size: size)
    }

    /// The lines `text` wraps to on a plate `plateWidth` wide.
    static func lines(_ text: String, plateWidth: CGFloat, compact: Bool) -> Int {
        let f = font(compact: compact)
        let w = max(plateWidth - 2 * horizontalPadding, 1)
        let rect = (text as NSString).boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude),
                                                   options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                   attributes: [.font: f], context: nil)
        return max(Int((rect.height / max(f.lineHeight, 1) - 0.05).rounded(.up)), 1)
    }

    /// The widest single word (a word wider than the plate would be broken or cut).
    static func longestWord(_ text: String, compact: Bool) -> CGFloat {
        let f = font(compact: compact)
        let widths = text.split(separator: " ").map { (String($0) as NSString).size(withAttributes: [.font: f]).width }
        return widths.max() ?? 0
    }

    /// Fits in `maxLines` lines with every word whole.
    static func fits(_ text: String, plateWidth: CGFloat, compact: Bool) -> Bool {
        lines(text, plateWidth: plateWidth, compact: compact) <= maxLines
            && longestWord(text, compact: compact) <= plateWidth - 2 * horizontalPadding
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
/// Skip takes touches (QA-1 #11): a tap anywhere else on the card reaches the scene (tap to snap on phones). On a
/// hinge, step 2 shows the 160° → 138° clap beside its line (ROUND-3 founder call).
struct LessonCard: View {
    let lesson: LessonDisplay
    let compact: Bool
    var reduceMotion = false
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
            HStack(alignment: .top, spacing: compact ? 8 : 12) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
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
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                if lesson.showsClap {
                    Spacer(minLength: 0)
                    DuoClapDiagram(reduceMotion: reduceMotion)
                        .frame(width: compact ? 84 : 104, height: compact ? 66 : 82)
                }
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

/// The lesson's last card: "Snaps run out. Big bites earn them back.", the four rules, and a pointer to the snaps row
/// (ringed on screen: REVIEW-2 #12). Then Feed.
struct LessonFinalCard: View {
    @ObservedObject var controller: GameController
    let compact: Bool
    /// The HUD hugs the right edge (the pointer arrow aims at the snaps' corner).
    var trailing = true

    static let rules = "Every snap costs one. Three bugs in one bite give one back. Bees cost one more. "
        + "Wait too long and a snap wilts."
    static let snapsLine = "These are your snaps"

    var body: some View {
        VStack(spacing: compact ? 8 : 14) {
            SnapOverline(text: "First Bite done", compact: compact, color: SnapTheme.gold)
            Text(LessonScript.line(.done, touch: controller.touchWording))
                .font(SnapType.title(compact))
                .foregroundStyle(SnapTheme.cream)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(Self.rules)
                .font(SnapType.body(compact))
                .foregroundStyle(SnapTheme.mist)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text(Self.snapsLine)
                    .font(SnapType.body(compact))
                    .foregroundStyle(SnapTheme.limeLight)
                Image(systemName: trailing ? "arrow.down.right" : "arrow.down.left")
                    .font(.system(size: compact ? 14 : 17, weight: .heavy))
                    .foregroundStyle(SnapTheme.limeLight)
            }
            .accessibilityElement(children: .combine)
            if compact {
                // Side by side on a short phone, so the card stays clear of the snaps row it points at.
                HStack(spacing: 8) {
                    SnapButton(kind: .secondary, height: 52, compact: true, action: { controller.finishLessonHome() }) {
                        Text("Home")
                    }
                    .frame(width: 96)
                    SnapButton(kind: .primary, height: 52, compact: true, action: { controller.finishLesson() }) {
                        Text("Start feeding")
                    }
                }
            } else {
                SnapButton(kind: .primary, height: SnapTheme.primaryHeight, compact: false,
                           action: { controller.finishLesson() }) {
                    Text("Start feeding")
                }
                SnapButton(kind: .quiet, height: SnapTheme.minTap, compact: false,
                           action: { controller.finishLessonHome() }) {
                    Text("Home")
                }
            }
        }
        .snapCard(padding: compact ? 14 : 22, radius: 28)
    }
}
