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
        let pause = HUDLayout.make(info).pause
        let headerH: CGFloat = c ? 46 : 64
        ZStack {
            SnapBackdrop()
            page(first, rect: info.leftPage, headerH: headerH, header: true, c)
            page(second, rect: info.rightPage, headerH: headerH, header: false, c)
            SnapRoundButton(systemImage: "chevron.backward", label: "Back") { controller.show(.home) }
                .position(x: pause.midX, y: pause.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
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
                .padding(.bottom, 16)
            }
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
        HStack(alignment: .top, spacing: compact ? 8 : 10) {
            ZStack {
                Circle()
                    .fill(found ? (species.isProtected ? SnapTheme.bee.opacity(0.18) : SnapTheme.lime.opacity(0.16))
                                : Color.black.opacity(0.25))
                BugPortrait(species: species, found: found)
                    .padding(compact ? 4 : 6)
            }
            .frame(width: compact ? 46 : 60, height: compact ? 46 : 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(found ? info.name : "???")
                    .font(SnapType.headline(compact))
                    .foregroundStyle(SnapTheme.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if found {
                    Text(Self.countLine(species, data: data))
                        .font(SnapType.caption(compact).monospacedDigit())
                        .foregroundStyle(species.isProtected ? SnapTheme.bee : SnapTheme.gold)
                    Text(info.joke)
                        .font(SnapType.caption(compact))
                        .foregroundStyle(SnapTheme.mist)
                        .lineLimit(compact ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(Self.clue(species))
                        .font(SnapType.caption(compact))
                        .foregroundStyle(SnapTheme.haze)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 70 : 104, alignment: .topLeading)
        .snapCard(padding: compact ? 8 : 10, radius: 18)
        .opacity(found ? 1 : 0.8)
        .accessibilityElement(children: .combine)
    }
}
