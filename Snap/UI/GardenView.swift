import SwiftUI

/// R6 the Garden (ROUND-6 founder decision 2): the eight trap varieties over the two halves of the Duo, four a side,
/// like the Bug Book. A grown one is drawn in its colours with its line, and a tap picks it (play, Home and Results
/// draw it from then on); one not grown yet is a silhouette with how it grows. The chosen one wears a gold ring.
struct GardenView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    static let title = "Garden"
    static let subline = "Same bite, new look."

    /// "3 of 8 grown". Pure; tested.
    static func countLine(_ data: ProgressData) -> String {
        "\(data.unlockedVarieties.count) of \(TrapVariety.allCases.count) grown"
    }

    var body: some View {
        let c = info.isCompact
        let all = TrapVariety.allCases
        let half = (all.count + 1) / 2
        let first = Array(all.prefix(half))
        let second = Array(all.dropFirst(half))
        let pause = HUDLayout.make(info).back
        let headerH = BugBookView.headerHeight(compact: c, pauseMaxY: pause.maxY, top: info.top)
        ZStack {
            BogBackdrop(controller: controller, glow: SnapTheme.limeLight)
            page(first, rect: info.leftPage, headerH: headerH, header: true, back: pause, c)
            page(second, rect: info.rightPage, headerH: headerH, header: false, back: pause, c)
            SnapRoundButton(systemImage: "chevron.backward", label: "Back") { controller.show(.home) }
                .position(x: pause.midX, y: pause.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
        .onDisappear { store.markVarietiesSeen() }
    }

    private func page(_ varieties: [TrapVariety], rect: CGRect, headerH: CGFloat, header: Bool, back: CGRect,
                      _ c: Bool) -> some View {
        let data = store.data
        let grown = data.unlockedVarieties
        let chosen = controller.trapVariety
        return VStack(alignment: .leading, spacing: c ? 6 : 10) {
            HStack(alignment: .bottom) {
                if header {
                    // R8: the display type.
                    DisplayText(text: Self.title, size: c ? 32 : 44, tilt: -2)
                        .fixedSize()
                    Text(Self.countLine(data))
                        .font(SnapType.body(c))
                        .foregroundStyle(SnapTheme.mist)
                } else {
                    Text(Self.subline)
                        .font(SnapType.caption(c))
                        .foregroundStyle(SnapTheme.haze)
                }
                Spacer(minLength: 0)
            }
            .frame(height: headerH, alignment: .bottom)
            // Clear of the back button where it sits in this page's header (R8: portrait's top left too).
            .padding(.trailing, info.headerPads(rect, back: back).trailing)
            .padding(.leading, info.headerPads(rect, back: back).leading)
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: c ? 8 : 10), GridItem(.flexible())],
                          spacing: c ? 8 : 10) {
                    ForEach(varieties, id: \.self) { v in
                        GardenCard(variety: v, grown: grown.contains(v), chosen: v == chosen,
                                   isNew: grown.contains(v) && !data.varietiesSeen.contains(v.rawValue), compact: c,
                                   onPick: { controller.chooseVariety(v) })
                    }
                }
                .padding(.bottom, 28)
            }
            .scrollColumn(initially: true)
        }
        .padding(.top, info.top - 8)
        .frame(width: rect.width, height: rect.height, alignment: .top)
        .position(x: rect.midX, y: rect.midY)
    }
}

/// One variety: its trap (or its silhouette), its name, and its line (or how it grows).
struct GardenCard: View {
    let variety: TrapVariety
    let grown: Bool
    let chosen: Bool
    let isNew: Bool
    let compact: Bool
    let onPick: () -> Void

    /// What the card says under the name ("Rank: …" or "Goal: …" while locked: R7 #19). Pure; tested.
    static func line(_ v: TrapVariety, grown: Bool) -> String {
        grown ? VarietyBridge.blurb(v) : VarietyBridge.rule(v)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: onPick) {
            VStack(spacing: compact ? 3 : 6) {
                ZStack(alignment: .topTrailing) {
                    GardenTrapImage(variety: variety, grown: grown)
                        .frame(maxWidth: .infinity)
                        .frame(height: compact ? 58 : 100)
                    if chosen {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: compact ? 18 : 22, weight: .bold))
                            .foregroundStyle(SnapTheme.gold)
                            .shadow(color: SnapTheme.shadow.opacity(0.6), radius: 3)
                    } else if isNew {
                        Text("New")
                            .font(.system(size: compact ? 10 : 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(SnapTheme.ink)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(SnapTheme.gold))
                    } else if !grown {
                        Image(systemName: "lock.fill")
                            .font(.system(size: compact ? 12 : 15, weight: .bold))
                            .foregroundStyle(SnapTheme.haze)
                    }
                }
                Text(VarietyBridge.name(variety))
                    .font(SnapType.headline(compact))
                    .foregroundStyle(grown ? SnapTheme.cream : SnapTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(Self.line(variety, grown: grown))
                    .font(SnapType.caption(compact))
                    .foregroundStyle(grown ? SnapTheme.mist : SnapTheme.haze)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 120 : 176, alignment: .top)
            .snapCard(padding: compact ? 8 : 10, radius: 18)
            .overlay(shape.stroke(SnapTheme.gold, lineWidth: chosen ? 3 : 0))
            .opacity(grown ? 1 : 0.85)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!grown)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(VarietyBridge.name(variety) + (chosen ? ", chosen" : "")
                            + (grown ? "" : ". " + VarietyBridge.rule(variety)))
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

/// The variety's hero trap (the Scene's own 3/4 drawing in its colours), or its silhouette while it hasn't grown.
struct GardenTrapImage: View {
    let variety: TrapVariety
    let grown: Bool

    /// R7 (#19, frame 44: the locked outlines mixed spiky and smooth): every locked card is the same silhouette (the
    /// Classic's), so a lock never gives away a look; a grown one is drawn as itself. Pure; tested.
    static func drawn(_ v: TrapVariety, grown: Bool) -> TrapVariety { grown ? v : .classic }

    var body: some View {
        if let cg = TrapImageCache.heroImage(bug: false, variety: Self.drawn(variety, grown: grown)) {
            Image(decorative: cg, scale: TrapImageCache.scale)
                .renderingMode(grown ? .original : .template)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.black.opacity(0.55))
                .accessibilityHidden(true)
        } else if grown {
            TrapHeroArt()
        } else {
            Ellipse().fill(Color.black.opacity(0.45)).padding(10)
                .accessibilityHidden(true)
        }
    }
}
