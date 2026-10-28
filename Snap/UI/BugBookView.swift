import SwiftUI

/// The Bug Book: 16 pages over the two halves of the Duo (eight a side, like a real book). A found entry is drawn
/// (`TrapArt`), with its name, joke and the count caught (bees and wasps: spared); an unfound one is a silhouette.
struct BugBookView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    var body: some View {
        let c = info.isCompact
        let all = BugSpecies.allCases
        let half = (all.count + 1) / 2
        let first = Array(all.prefix(half))
        let second = Array(all.dropFirst(half))
        let pause = HUDLayout.make(info).back
        // The header row is tall enough that the back button sits in it, never over the first card (REVIEW-1 #13).
        let headerH = BugBookView.headerHeight(compact: c, pauseMaxY: pause.maxY, top: info.top)
        ZStack {
            BogBackdrop(controller: controller)
            page(first, rect: info.leftPage, headerH: headerH, header: true, c)
            page(second, rect: info.rightPage, headerH: headerH, header: false, c)
            SnapRoundButton(systemImage: "chevron.backward", label: "Back") { controller.show(.home) }
                .position(x: pause.midX, y: pause.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
    }

    /// The header's height: at least the type's, and down past the back button. Pure; tested.
    static func headerHeight(compact: Bool, pauseMaxY: CGFloat, top: CGFloat) -> CGFloat {
        max(compact ? 46 : 64, pauseMaxY + 4 - (top - 8))
    }

    private func page(_ species: [BugSpecies], rect: CGRect, headerH: CGFloat, header: Bool, _ c: Bool) -> some View {
        VStack(alignment: .leading, spacing: c ? 6 : 10) {
            HStack(alignment: .firstTextBaseline) {
                if header {
                    Text("Bug Book")
                        .font(SnapType.title(c))
                        .foregroundStyle(SnapTheme.cream)
                    Text("\(store.data.speciesFound) of \(BugSpecies.allCases.count) found")
                        .font(SnapType.body(c))
                        .foregroundStyle(SnapTheme.mist)
                } else {
                    Text("Caught one? It's in here for ever.")
                        .font(SnapType.caption(c))
                        .foregroundStyle(SnapTheme.haze)
                }
                Spacer(minLength: 0)
            }
            .frame(height: headerH, alignment: .bottom)
            .padding(.trailing, !header && !info.hudOnLeft ? 64 : 0)
            .padding(.leading, header && info.hudOnLeft ? 64 : 0)
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: c ? 8 : 10), GridItem(.flexible())],
                          spacing: c ? 8 : 10) {
                    ForEach(species, id: \.self) { s in
                        BugBookCard(species: s, data: store.data, compact: c)
                    }
                }
                .padding(.bottom, 28)
            }
            // A fade and a chevron at the foot say "there's more below" (REVIEW-2 #19: the fourth row).
            .scrollColumn(initially: true)
        }
        .padding(.top, info.top - 8)
        .frame(width: rect.width, height: info.size.height, alignment: .top)
        .position(x: rect.midX, y: info.size.height / 2)
    }
}

/// One Bug Book page.
struct BugBookCard: View {
    let species: BugSpecies
    let data: ProgressData
    let compact: Bool

    /// "Caught 34", "Spared 12", or how to find it. Pure; tested.
    static func countLine(_ s: BugSpecies, data: ProgressData) -> String {
        if s.isProtected { return "Spared \(data.sparedCount(s))" }
        return "Caught \(data.caughtCount(s))"
    }

    static func clue(_ s: BugSpecies) -> String {
        if s.isProtected { return "Spare one to fill this page" }
        switch BugCatalog.info(s).firstPhase {
        case .morning: return "Comes in the morning"
        case .noon: return "Comes at noon"
        case .dusk: return "Comes at dusk"
        case .night: return "Comes at night"
        }
    }

    var body: some View {
        let found = data.isFound(species)
        let info = BugCatalog.info(species)
        // The joke runs the card's full width under the portrait row, so it is never cut (REVIEW-1 #13).
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(alignment: .center, spacing: compact ? 8 : 10) {
                ZStack {
                    Circle()
                        .fill(found ? (species.isProtected ? SnapTheme.bee.opacity(0.18) : SnapTheme.lime.opacity(0.16))
                                    : Color.black.opacity(0.25))
                    BugPortrait(species: species, found: found)
                        .padding(compact ? 2 : 3)
                }
                .frame(width: compact ? 44 : 56, height: compact ? 44 : 56)
                VStack(alignment: .leading, spacing: 1) {
                    Text(found ? info.name : "???")
                        .font(SnapType.headline(compact))
                        .foregroundStyle(SnapTheme.cream)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                    if found {
                        Text(Self.countLine(species, data: data))
                            .font(SnapType.caption(compact).monospacedDigit())
                            .foregroundStyle(species.isProtected ? SnapTheme.bee : SnapTheme.gold)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(found ? info.joke : Self.clue(species))
                .font(SnapType.caption(compact))
                .foregroundStyle(found ? SnapTheme.mist : SnapTheme.haze)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 92 : 118, alignment: .topLeading)
        .snapCard(padding: compact ? 8 : 10, radius: 18)
        .opacity(found ? 1 : 0.8)
        .accessibilityElement(children: .combine)
    }
}
