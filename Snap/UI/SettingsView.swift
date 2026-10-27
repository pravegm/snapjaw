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
        let pause = HUDLayout.make(info).pause
        ZStack {
            SnapBackdrop()
            ScrollView(showsIndicators: false) {
                toggles(c)
                    .padding(.top, info.top)
                    .padding(.bottom, 20)
            }
            .frame(width: info.otherPage.width, height: info.size.height)
            .position(x: info.otherPage.midX, y: info.size.height / 2)
            ScrollView(showsIndicators: false) {
                about(c)
                    .padding(.top, info.top + (c ? 44 : 56))
                    .padding(.bottom, 20)
            }
            .frame(width: info.hudPage.width, height: info.size.height)
            .position(x: info.hudPage.midX, y: info.size.height / 2)
            SnapRoundButton(systemImage: "chevron.backward", label: "Back") { controller.show(.home) }
                .position(x: pause.midX, y: pause.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
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
                if BuildChannel.current != .appStore {
                    Text(BuildChannel.current.label + " · input " + controller.input.rawValue
                         + (controller.hasHinge ? " · hinge " + AppTrace.fixed(controller.hinge.angle ?? 0, 0) + "°"
                                                : ""))
                        .font(SnapType.caption(c).monospacedDigit())
                        .foregroundStyle(SnapTheme.haze)
                }
            }
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
            }
            .snapCard(padding: c ? 10 : 14, radius: 22)
        }
    }
}
