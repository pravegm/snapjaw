import SwiftUI

/// Settings: Sound, Haptics, Respect silent switch, HUD on the left, Reduce motion (one page); Replay First Bite, Game
/// Center, About and Credits (the other).
struct SettingsView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    var body: some View {
        let c = info.isCompact
        let pause = HUDLayout.make(info).back
        ZStack {
            BogBackdrop(controller: controller)
            ScrollView(showsIndicators: false) {
                // R8 portrait: under the back button (it sits on this, the top, page there).
                toggles(c)
                    .padding(.top, info.columnTop(info.otherPage, back: pause))
                    .padding(.bottom, 28)
            }
            .scrollColumn()
            .frame(width: info.otherPage.width, height: info.otherPage.height)
            .position(x: info.otherPage.midX, y: info.otherPage.midY)
            ScrollView(showsIndicators: false) {
                // Starts under the back button (REVIEW-1 juror 11), all cards one width.
                about(c)
                    .padding(.top, info.columnTop(info.hudPage, back: pause))
                    .padding(.bottom, 28)
            }
            .scrollColumn(initially: true)
            .frame(width: info.hudPage.width, height: info.hudPage.height)
            .position(x: info.hudPage.midX, y: info.hudPage.midY)
            SnapRoundButton(systemImage: "chevron.backward", label: "Back") { controller.show(.home) }
                .position(x: pause.midX, y: pause.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
    }

    /// A fade at the foot of a scrolling column: there's more below (with `scrollColumn()`).
    /// R4 (REVIEW-3 #13: the chevron sat on "for her", "Absolutely not on the menu", "eaten."): the column's foot
    /// is a clear gutter the chevron sits in, under the fade, so no text is ever under it.
    static var footFade: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 36)
            Color.clear
                .frame(height: ScrollColumnCue.gutter)
        }
    }

    private func toggles(_ c: Bool) -> some View {
        VStack(alignment: .leading, spacing: c ? 8 : 12) {
            // R8: the display type.
            DisplayText(text: "Settings", size: c ? 34 : 46, tilt: -2)
                .fixedSize()
                .padding(.bottom, c ? 2 : 6)
            VStack(spacing: 0) {
                row("Sound", detail: "The CHOMP, the buzz, the bog", isOn: $settings.soundOn, c)
                divider
                row("Haptics", detail: "Feel every landing and bite", isOn: $settings.hapticsOn, c)
                divider
                row("Respect silent switch", detail: "Quiet when your iPhone is on silent",
                    isOn: $settings.respectSilentSwitch, c)
                divider
                // R5 (REVIEW-4 #13, founder call): plain words, not "HUD".
                row(Self.hudSideTitle, detail: Self.hudSideDetail, isOn: $settings.hudOnLeft, c)
                divider
                row("Reduce motion", detail: "Calmer shakes and pops", isOn: $settings.reduceMotion, c)
            }
            .snapCard(padding: c ? 10 : 14, radius: 22)
        }
    }

    static let hudSideTitle = "Score on the left"
    static let hudSideDetail = "Your score and snaps on the left half"

    /// The diagnostics line: TestFlight on a device with a hinge only. Pure; tested.
    static func showsDiagnostics(channel: BuildChannel.Kind, hasHinge: Bool) -> Bool {
        channel == .testFlight && hasHinge
    }

    private var divider: some View {
        Rectangle().fill(SnapTheme.stroke).frame(height: 1)
    }

    private func row(_ title: String, detail: String, isOn: Binding<Bool>, _ c: Bool) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SnapType.body(c))
                    .foregroundStyle(SnapTheme.cream)
                Text(detail)
                    .font(SnapType.caption(c))
                    .foregroundStyle(SnapTheme.haze)
            }
        }
        .tint(SnapTheme.lime)
        .frame(minHeight: c ? 48 : SnapTheme.minTap)
    }

    private func about(_ c: Bool) -> some View {
        VStack(alignment: .leading, spacing: c ? 8 : 12) {
            // R8: the First Bite is retired: Levels 1–5 teach, any time, from the map.
            SnapButton(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c,
                       action: { controller.show(.levels) }) {
                Label("Levels", systemImage: "map.fill")
            }
            SnapButton(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c,
                       action: { controller.showGameCenter() }) {
                Label("Game Center", systemImage: "trophy.fill")
            }
            VStack(alignment: .leading, spacing: 6) {
                SnapOverline(text: "About", compact: c)
                Text("\(AppBrand.name) \(BuildChannel.versionLine)")
                    .font(SnapType.headline(c))
                    .foregroundStyle(SnapTheme.cream)
                Text(AppBrand.tagline + " Made for iPhone Duo: the phone is the trap. Close it to bite. "
                     + "No ads, no purchases, no data collected.")
                    .font(SnapType.caption(c))
                    .foregroundStyle(SnapTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
                // REVIEW-2 #20: no "Debug · input touch" line. TestFlight builds on a Duo keep the hinge angle (the
                // founder's device checks); nothing else ever shows it.
                if Self.showsDiagnostics(channel: BuildChannel.current, hasHinge: controller.hasHinge) {
                    Text("TestFlight · hinge " + AppTrace.fixed(controller.hinge.angle ?? 0, 0) + "°")
                        .font(SnapType.caption(c).monospacedDigit())
                        .foregroundStyle(SnapTheme.haze)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .snapCard(padding: c ? 10 : 14, radius: 22)
            VStack(alignment: .leading, spacing: 6) {
                SnapOverline(text: "Credits", compact: c)
                Text("Design, code, sound and bugs: a tiny studio and a lot of flies. Sounds are synthesised live. "
                     + "No bees were eaten.")
                    .font(SnapType.caption(c))
                    .foregroundStyle(SnapTheme.mist)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Lifetime: \(AppRules.formatted(store.data.lifetimeBugs)) bugs caught, "
                     + "\(AppRules.formatted(store.data.lifetimeSpared)) bees spared")
                    .font(SnapType.caption(c))
                    .foregroundStyle(SnapTheme.haze)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .snapCard(padding: c ? 10 : 14, radius: 22)
        }
    }
}

/// A scrolling page column: the foot fade, and a "more below" chevron that shows until the end is reached
/// (REVIEW-2 #19, #20: the Bug Book's fourth row and the clipped Credits had no cue).
struct ScrollColumnCue: ViewModifier {
    /// The clear band at the foot of the column (the chevron's), kept free of content by a matching bottom margin.
    static let gutter: CGFloat = 40
    @State private var more: Bool

    init(initially: Bool) {
        _more = State(initialValue: initially)
    }

    func body(content: Content) -> some View {
        content
            // The last card can always scroll up out of the gutter.
            .contentMargins(.bottom, Self.gutter, for: .scrollContent)
            .onScrollGeometryChange(for: Bool.self) { g in
                g.contentOffset.y + g.containerSize.height < g.contentSize.height - 12
            } action: { _, new in
                more = new
            }
            .mask { SettingsView.footFade }
            .overlay(alignment: .bottom) {
                if more {
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(SnapTheme.limeLight)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(SnapTheme.surface.opacity(0.88)))
                        .overlay(Capsule().stroke(SnapTheme.lime.opacity(0.3), lineWidth: 1))
                        .padding(.bottom, (Self.gutter - 30) / 2)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .animation(.easeOut(duration: 0.2), value: more)
    }
}

extension View {
    /// A scrolling page column's foot fade and its "more below" cue (`initially`: shown before the first measure).
    func scrollColumn(initially: Bool = false) -> some View {
        modifier(ScrollColumnCue(initially: initially))
    }
}
