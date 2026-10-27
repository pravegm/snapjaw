import SwiftUI

/// The play layer over the scene: the HUD in the corners of the HUD page (outside the trap ellipse where it fits, so
/// it never covers bugs), the hint, the lesson card, the pause menu and the closing card. Only the buttons take
/// touches: every tap elsewhere reaches the scene (tap to snap on iPhones without a hinge).
struct PlayLayer: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDState
    let info: AppCanvas

    var body: some View {
        let l = HUDLayout.make(info)
        let v = hud.values
        let c = info.isCompact
        let paused = controller.isMenuOpen || controller.isClosingPaused
        let lesson = controller.route == .lesson ? controller.lessonDisplay : nil
        ZStack {
            if !v.lesson {
                ScoreBlock(score: v.score, best: v.best, passedBest: v.passedBest, trailing: l.trailing, compact: c)
                    .frame(width: l.score.width, height: l.score.height,
                           alignment: l.trailing ? .topTrailing : .topLeading)
                    .position(x: l.score.midX, y: l.score.midY)
                    .allowsHitTesting(false)
                if v.chainMultiplier > 1.01 {
                    ChainChip(multiplier: v.chainMultiplier, compact: c)
                        .frame(width: l.chain.width, height: l.chain.height,
                               alignment: l.trailing ? .trailing : .leading)
                        .position(x: l.chain.midX, y: l.chain.midY)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
                SnapsRow(left: v.snapsLeft, max: v.snapsMax, trailing: l.trailing)
                    .frame(width: l.snaps.width, height: l.snaps.height,
                           alignment: l.trailing ? .trailing : .leading)
                    .position(x: l.snaps.midX, y: l.snaps.midY)
                    .allowsHitTesting(false)
            }
            if !paused {
                HintPlate(hint: v.hint, banner: v.banner, touch: controller.touchWording, compact: c)
                    .frame(width: l.hint.width, height: l.hint.height,
                           alignment: l.trailing ? .trailing : .leading)
                    .position(x: l.hint.midX, y: l.hint.midY)
                    .allowsHitTesting(false)
            }
            if let marker = controller.dailyMarker, !paused, !v.lesson {
                Text(marker.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(SnapTheme.goldLight)
                    .snapLegible()
                    .position(x: l.chain.midX, y: l.chain.maxY + 14)
                    .allowsHitTesting(false)
            }
            if v.tired {
                TiredBanner(compact: c)
                    .position(x: info.trapRect.midX, y: info.size.height * 0.5)
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
                    LessonCard(lesson: lesson, compact: c, onSkip: { controller.skipLesson() })
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
                .font(SnapType.number(compact ? 38 : 48))
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

/// The chain multiplier chip ("Chain ×2").
struct ChainChip: View {
    let multiplier: Double
    let compact: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: compact ? 12 : 14, weight: .heavy))
            Text("Chain " + AppRules.multiplierText(multiplier))
                .font(.system(size: compact ? 14 : 17, weight: .heavy, design: .rounded).monospacedDigit())
        }
        .foregroundStyle(SnapTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(LinearGradient(colors: [SnapTheme.goldLight, SnapTheme.gold], startPoint: .top,
                                                  endPoint: .bottom)))
        .overlay(Capsule().stroke(SnapTheme.goldDeep, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}

/// The snaps as little trap icons (up to 12): filled for each snap left, hollow up to the starting ten.
struct SnapsRow: View {
    let left: Int
    let max: Int
    let trailing: Bool

    static func slots(left: Int, max: Int) -> Int {
        Swift.min(Swift.max(Swift.max(left, Tuning.startSnaps), 0), Swift.max(max, 1))
    }

    var body: some View {
        let count = Self.slots(left: left, max: max)
        HStack(spacing: HUDLayout.snapGap) {
            if trailing { Spacer(minLength: 0) }
            Text("\(Swift.max(left, 0))")
                .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(left <= 1 ? SnapTheme.danger : SnapTheme.cream)
                .snapLegible()
                .padding(.trailing, 4)
            ForEach(0..<count, id: \.self) { i in
                let filled = i < left
                SnapGlyph()
                    .fill(filled ? AnyShapeStyle(LinearGradient(colors: [SnapTheme.pink, SnapTheme.crimson],
                                                                startPoint: .top, endPoint: .bottom))
                                 : AnyShapeStyle(Color.black.opacity(0.35)))
                    .overlay(SnapGlyph().stroke(filled ? SnapTheme.lime : SnapTheme.haze.opacity(0.6), lineWidth: 1.5))
                    .frame(width: HUDLayout.snapIcon, height: HUDLayout.snapIcon * 0.82)
            }
            if !trailing { Spacer(minLength: 0) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Swift.max(left, 0)) snaps left")
    }
}

/// The one-line hint (or the run-start line), on a cream plate (warnings on crimson).
struct HintPlate: View {
    let hint: TrapHint?
    let banner: String?
    let touch: Bool
    let compact: Bool

    var body: some View {
        ZStack {
            if let hint, let text = AppRules.hintText(hint, touch: touch) {
                let warn = AppRules.hintIsWarning(hint)
                Text(text)
                    .font(SnapType.hint(compact))
                    .foregroundStyle(warn ? SnapTheme.cream : SnapTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(warn ? SnapTheme.crimson : SnapTheme.cream))
                    .overlay(Capsule().stroke(warn ? SnapTheme.pink : SnapTheme.lime, lineWidth: 2))
                    .shadow(color: SnapTheme.shadow.opacity(0.5), radius: 8, y: 3)
                    .id(text)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .accessibilityLabel(text)
            } else if let banner {
                Text(banner)
                    .font(SnapType.headline(compact))
                    .foregroundStyle(SnapTheme.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(SnapTheme.surface.opacity(0.85)))
                    .overlay(Capsule().stroke(SnapTheme.lime.opacity(0.4), lineWidth: 1.5))
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

/// The closing pause: "Open it a little to carry on" (θ under 50° for 0.6 s). Nothing steps until it's open again.
struct ClosingCard: View {
    @ObservedObject var controller: GameController
    let info: AppCanvas
    let layout: HUDLayout

    static let title = "Open it a little to carry on"
    static let detail = "The bugs are waiting. So is your trap."

    var body: some View {
        let c = info.isCompact
        ZStack {
            Color.black.opacity(0.5)
                .contentShape(Rectangle())
                .onTapGesture {}
            VStack(spacing: c ? 10 : 14) {
                TrapPortrait(closure01: 0.85)
                    .frame(width: c ? 130 : 170, height: c ? 92 : 120)
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

/// One sentence per step, the step number, praise (green-gold) or a warning (crimson), and Skip after step 2.
struct LessonCard: View {
    let lesson: LessonDisplay
    let compact: Bool
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack {
                SnapOverline(text: "First Bite · " + lesson.stepOf, compact: compact)
                Spacer(minLength: 6)
                if lesson.allowsSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(SnapType.body(compact))
                            .foregroundStyle(SnapTheme.mist)
                            .frame(minWidth: SnapTheme.minTap, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Skip the lesson")
                }
            }
            Text(lesson.line)
                .font(SnapType.headline(compact))
                .foregroundStyle(SnapTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
            if let praise = lesson.praise {
                Text(praise)
                    .font(SnapType.hint(compact))
                    .foregroundStyle(SnapTheme.gold)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if let warning = lesson.warning {
                Text(warning)
                    .font(SnapType.body(compact))
                    .foregroundStyle(SnapTheme.pink)
                    .transition(.opacity)
            }
        }
        .snapCard(padding: compact ? 10 : 14, radius: 20)
        .animation(.easeOut(duration: 0.2), value: lesson)
        .accessibilityElement(children: .combine)
    }
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
            Text("Every snap costs one. Three bugs in one bite give one back. Bees cost one more.")
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
