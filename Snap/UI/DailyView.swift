import SwiftUI

/// The Daily Bog: the same bog for everyone today, one scored try (then practice), today's score and best practice,
/// and the last few days.
struct DailyView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    /// What today's card says. Pure; tested.
    static func status(canPlay: Bool, record: DailyRecord?) -> String {
        if canPlay { return "One scored try today. Make it a feast." }
        guard let record else { return "Today's try is used. Practise all you like." }
        // R5 (REVIEW-4 #13): "score", not "protein".
        if !record.finished { return "Today's try ended early, with a score of \(AppRules.formatted(record.score))." }
        return "Today's score: \(AppRules.formatted(record.score))."
    }

    var body: some View {
        let c = info.isCompact
        let today = controller.today
        let canPlay = store.canPlayScoredDaily(today: today)
        let record = store.data.dailyRecord(day: today)
        let pause = HUDLayout.make(info).back
        ZStack {
            BogBackdrop(controller: controller, glow: SnapTheme.gold)
            VStack(spacing: c ? 8 : 14) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: c ? 40 : 56, weight: .bold))
                    .foregroundStyle(SnapTheme.gold)
                    .shadow(color: SnapTheme.gold.opacity(0.5), radius: 18)
                Text(AppRules.dailyTitle(day: today))
                    .font(SnapType.title(c))
                    .foregroundStyle(SnapTheme.cream)
                    .multilineTextAlignment(.center)
                Text("Same bog, same bugs, for everyone today.")
                    .font(SnapType.body(c))
                    .foregroundStyle(SnapTheme.mist)
                    .multilineTextAlignment(.center)
                history(today: today, c)
            }
            .frame(width: min(info.otherPage.width, 420))
            .position(x: info.otherPage.midX, y: info.size.height / 2)
            VStack(spacing: c ? 8 : 12) {
                Text(Self.status(canPlay: canPlay, record: record))
                    .font(SnapType.headline(c))
                    .foregroundStyle(SnapTheme.cream)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let record, record.practiceBest > 0 {
                    Text("Best practice " + AppRules.formatted(record.practiceBest))
                        .font(SnapType.body(c).monospacedDigit())
                        .foregroundStyle(SnapTheme.mist)
                }
                if canPlay {
                    SnapButton(kind: .primary, height: c ? 58 : 68, compact: c, action: { controller.playDaily() }) {
                        Label("Play today's bog", systemImage: "sun.max.fill")
                    }
                } else {
                    SnapButton(kind: .primary, height: c ? 58 : 68, compact: c, action: { controller.practiseDaily() }) {
                        Label("Practise", systemImage: "arrow.clockwise")
                    }
                }
                if store.data.bestDaily > 0 {
                    Text("Your best Daily Bog: " + AppRules.formatted(store.data.bestDaily))
                        .font(SnapType.caption(c))
                        .foregroundStyle(SnapTheme.haze)
                }
            }
            .frame(width: min(info.hudPage.width, 360))
            .snapCard(padding: c ? 12 : 18, radius: 24)
            .position(x: info.hudPage.midX, y: info.size.height / 2 + (c ? 12 : 16))
            SnapRoundButton(systemImage: "chevron.backward", label: "Back") { controller.show(.home) }
                .position(x: pause.midX, y: pause.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
    }

    /// The last few days played.
    @ViewBuilder
    private func history(today: Int, _ c: Bool) -> some View {
        let days = store.data.daily.keys.filter { $0 < today }.sorted(by: >).prefix(4)
        if !days.isEmpty {
            VStack(spacing: 4) {
                ForEach(Array(days), id: \.self) { day in
                    HStack {
                        Text(AppRules.dailyDate(day: day))
                            .font(SnapType.caption(c))
                            .foregroundStyle(SnapTheme.mist)
                        Spacer()
                        Text(AppRules.formatted(store.data.daily[day]?.score ?? 0))
                            .font(SnapType.caption(c).monospacedDigit())
                            .foregroundStyle(SnapTheme.gold)
                    }
                }
            }
            .frame(maxWidth: 260)
            .snapCard(padding: c ? 8 : 12, radius: 16)
        }
    }
}
