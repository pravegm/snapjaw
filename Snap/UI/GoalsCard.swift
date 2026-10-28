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
    /// R7 (#15): each goal's tier as a word beside its dot (Home: one easy, one medium, one hard, labelled).
    var tierLabels = false
    /// R7 (#7): the bars under goals under way (Results' tightest fit drops them).
    var bars = true

    static let homeTitle = "Goals"

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 7) {
            SnapOverline(text: title, compact: compact, color: SnapTheme.gold)
            ForEach(lines) { line in
                GoalRow(line: line, compact: compact, tierLabel: tierLabels, bar: bars)
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
    /// R7 (#15): the tier's word beside its dot.
    var tierLabel = false
    var bar = true

    /// R7 (#15): a tier's colour: easy lime, medium gold, hard pink. Exhaustive over Core's tiers.
    static func tierColor(_ t: GoalTier) -> Color {
        switch t {
        case .easy: return SnapTheme.limeLight
        case .medium: return SnapTheme.gold
        case .hard: return SnapTheme.pink
        }
    }

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
                if bar && !line.done && line.target > 1 {
                    SnapProgressBar(value: line.fraction, height: compact ? 3 : 4)
                }
            }
            Spacer(minLength: 4)
            if let t = line.tier {
                TierDot(tier: t, compact: compact, label: tierLabel)
            }
            Text(line.countText)
                .font(SnapType.caption(compact).monospacedDigit())
                .foregroundStyle(line.done ? SnapTheme.lime : SnapTheme.mist)
                .lineLimit(1)
                .fixedSize()
        }
        // A goal this run doesn't count (or can't meet any more) is drawn dimmed.
        .opacity(line.inPlay && !line.spoiled ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.title + (line.tier == nil ? "" : ", " + line.tierLabel)
                            + (line.done ? ", done" : ", " + line.countText))
    }
}

/// R7 (#15): a goal's tier: a coloured dot, with its word ("Easy") where there's room.
struct TierDot: View {
    let tier: GoalTier
    let compact: Bool
    var label = false

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(GoalRow.tierColor(tier))
                .frame(width: compact ? 7 : 8, height: compact ? 7 : 8)
            if label {
                Text(tier.label)
                    .font(.system(size: compact ? 9 : 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(GoalRow.tierColor(tier))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .accessibilityHidden(true)
    }
}
