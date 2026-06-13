import SwiftUI

// MARK: - Pulse block (parity with web Skeleton)

struct Skeleton: View {
  @Environment(\.appPalette) private var palette

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
      let phase = timeline.date.timeIntervalSinceReferenceDate
      let opacity = 0.35 + 0.35 * (sin(phase * 2 * .pi / 1.2) + 1) / 2

      Rectangle()
        .fill(palette.border.opacity(opacity))
    }
    .accessibilityHidden(true)
  }
}

// MARK: - Section skeletons (parity with web list-skeletons.tsx)

struct ExpenseHeroSkeleton: View {
  var body: some View {
    TerminalCard {
      VStack(alignment: .leading, spacing: 8) {
        Skeleton()
          .frame(width: 80, height: 10)
        Skeleton()
          .frame(width: 140, height: 36)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("loading period")
  }
}

struct ExpensePeriodListSkeleton: View {
  @Environment(\.appPalette) private var palette

  var rows: Int = 4

  var body: some View {
    VStack(spacing: 8) {
      ForEach(0..<rows, id: \.self) { _ in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Skeleton()
              .frame(width: 120, height: 14)
            Spacer(minLength: 8)
            Skeleton()
              .frame(width: 56, height: 14)
          }
          Skeleton()
            .frame(width: 96, height: 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("loading spendings")
  }
}

struct CardListSkeleton: View {
  var count: Int = 3
  var label: String = "loading"

  var body: some View {
    VStack(spacing: 16) {
      ForEach(0..<count, id: \.self) { _ in
        TerminalCard(showsGlow: false) {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Skeleton()
                .frame(width: 120, height: 14)
              Spacer()
              Skeleton()
                .frame(width: 64, height: 16)
            }
            Skeleton()
              .frame(width: 180, height: 10)
            Skeleton()
              .frame(width: 140, height: 10)
            Skeleton()
              .frame(maxWidth: .infinity, minHeight: 4, maxHeight: 4)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(label)
  }
}

struct ProjectionsListSkeleton: View {
  @Environment(\.appPalette) private var palette

  var rows: Int = 5

  var body: some View {
    VStack(spacing: 12) {
      Skeleton()
        .frame(width: 200, height: 10)

      ForEach(0..<rows, id: \.self) { _ in
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Skeleton()
              .frame(width: 72, height: 14)
            Spacer()
            Skeleton()
              .frame(width: 120, height: 10)
          }
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Skeleton()
                .frame(width: 28, height: 8)
              Skeleton()
                .frame(width: 80, height: 22)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
              Skeleton()
                .frame(width: 32, height: 8)
              Skeleton()
                .frame(width: 72, height: 22)
            }
          }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .overlay(Rectangle().stroke(palette.border, lineWidth: 1))
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("loading projections")
  }
}
