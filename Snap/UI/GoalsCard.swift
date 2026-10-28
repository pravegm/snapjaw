import SwiftUI

/// R6 goals: the three goals on a card (Home, the pause menu, Results). Each line ticks when done, with a thin bar for
/// a goal of more than one step and its count ("2/3").
struct GoalsCard: View {
    let lines: [GoalLine]
    let compact: Bool
    var title = GoalsCard.homeTitle
    /// Under the lines ("+60 growth", "New goals are on Home").
    var footer: String?
    var footerColor: Color = SnapTheme.limeLight

    static let homeTitle = "Goals"

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 7) {
            SnapOverline(text: title, compact: compact, color: SnapTheme.gold)
            ForEach(lines) { line in
                GoalRow(line: line, compact: compact)
            }
            if let footer {
                Text(footer)
                    .font(SnapType.caption(compact).weight(.bold))
                    .foregroundStyle(footerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard(padding: compact ? 10 : 12, radius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// One goal: a tick (or an empty ring), its words, its count; a thin bar under the words while it's under way.
struct GoalRow: View {
    let line: GoalLine
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: line.done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: compact ? 14 : 17, weight: .bold))
                .foregroundStyle(line.done ? SnapTheme.lime : SnapTheme.haze)
                .frame(width: compact ? 16 : 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .font(SnapType.caption(compact).weight(.semibold))
                    .foregroundStyle(line.done ? SnapTheme.limeLight : SnapTheme.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !line.done && line.target > 1 {
                    SnapProgressBar(value: line.fraction, height: compact ? 3 : 4)
                }
            }
            Spacer(minLength: 4)
            Text(line.countText)
                .font(SnapType.caption(compact).monospacedDigit())
                .foregroundStyle(line.done ? SnapTheme.lime : SnapTheme.mist)
                .lineLimit(1)
                .fixedSize()
        }
        // A goal this run doesn't count (or can't meet any more) is drawn dimmed.
        .opacity(line.inPlay && !line.spoiled ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.title + (line.done ? ", done" : ", " + line.countText))
    }
}
