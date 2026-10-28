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
                toggles(c)
                    .padding(.top, info.top)
                    .padding(.bottom, 28)
            }
            .scrollColumn()
            .frame(width: info.otherPage.width, height: info.size.height)
            .position(x: info.otherPage.midX, y: info.size.height / 2)
            ScrollView(showsIndicators: false) {
                // Starts under the back button (REVIEW-1 juror 11), all cards one width.
                about(c)
                    .padding(.top, pause.maxY + 10)
                    .padding(.bottom, 28)
            }
            .scrollColumn(initially: true)
            .frame(width: info.hudPage.width, height: info.size.height)
            .position(x: info.hudPage.midX, y: info.size.height / 2)
            SnapRoundButton(systemImage: "chevron.backward", label: "Back") { controller.show(.home) }
                .position(x: pause.midX, y: pause.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
    }

    /// A fade at the foot of a scrolling column: there's more below (with `scrollColumn()`).
    static var footFade: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 36)
        }
    }

    private func toggles(_ c: Bool) -> some View {
        VStack(alignment: .leading, spacing: c ? 8 : 12) {
            Text("Settings")
                .font(SnapType.title(c))
                .foregroundStyle(SnapTheme.cream)
            VStack(spacing: 0) {
                row("Sound", detail: "The CHOMP, the buzz, the bog", isOn: $settings.soundOn, c)
                divider
                row("Haptics", detail: "Feel every landing and bite", isOn: $settings.hapticsOn, c)
                divider
                row("Respect silent switch", detail: "Quiet when your iPhone is on silent",
                    isOn: $settings.respectSilentSwitch, c)
                divider
                row("HUD on the left", detail: "Score and snaps on the other half", isOn: $settings.hudOnLeft, c)
                divider
                row("Reduce motion", detail: "Calmer shakes and pops", isOn: $settings.reduceMotion, c)
            }
            .snapCard(padding: c ? 10 : 14, radius: 22)
        }
    }

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
            SnapButton(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c,
                       action: { controller.replayLesson() }) {
                Label("Replay First Bite", systemImage: "graduationcap.fill")
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
                Text(AppBrand.tagline + " Made for iPhone Duo: hold it like a book, snap it a little shut. "
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
    @State private var more: Bool

    init(initially: Bool) {
        _more = State(initialValue: initially)
    }

    func body(content: Content) -> some View {
        content
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
                        .padding(.bottom, 8)
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
