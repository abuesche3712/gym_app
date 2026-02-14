//
//  AnalyticsCharts.swift
//  gym app
//
//  Analytics chart and chart-row views.
//

import SwiftUI

struct VolumeTrendBars: View {
    let points: [WeeklyVolumePoint]

    private var maxVolume: Double {
        max(points.map(\.totalVolume).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                VStack(spacing: 4) {
                    Capsule()
                        .fill(point.totalVolume > 0 ? AppColors.dominant : AppColors.surfaceTertiary)
                        .frame(width: 10, height: barHeight(for: point))

                    if index == 0 || index == points.count - 1 {
                        Text(formatMonthDay(point.weekStart))
                            .caption2(color: AppColors.textTertiary)
                    } else {
                        Color.clear
                            .frame(height: 10)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for point: WeeklyVolumePoint) -> CGFloat {
        let normalized = point.totalVolume / maxVolume
        return max(8, CGFloat(normalized * 72))
    }
}

struct E1RMTrendChart: View {
    let points: [E1RMProgressPoint]

    private let horizontalPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 10

    private var minValue: Double {
        points.map(\.estimatedOneRepMax).min() ?? 0
    }

    private var maxValue: Double {
        points.map(\.estimatedOneRepMax).max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let chartPoints = normalizedPoints(in: size)

            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.surfaceSecondary)

                if chartPoints.count >= 2 {
                    Path { path in
                        path.move(to: chartPoints[0])
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(AppColors.dominant, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let position = chartPoints[index]
                    Circle()
                        .fill(index == points.count - 1 ? AppColors.warning : AppColors.dominant)
                        .frame(width: index == points.count - 1 ? 8 : 6, height: index == points.count - 1 ? 8 : 6)
                        .position(position)
                        .accessibilityLabel("\(formatMonthDay(point.date)), estimated 1RM \(formatWeight(point.estimatedOneRepMax)) pounds")
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        let plotWidth = max(1, size.width - (horizontalPadding * 2))
        let plotHeight = max(1, size.height - (verticalPadding * 2))
        let range = max(maxValue - minValue, 1)

        return points.enumerated().map { index, point in
            let x: CGFloat
            if points.count == 1 {
                x = size.width / 2
            } else {
                x = horizontalPadding + (CGFloat(index) / CGFloat(points.count - 1)) * plotWidth
            }

            let normalizedY = (point.estimatedOneRepMax - minValue) / range
            let y = size.height - verticalPadding - (CGFloat(normalizedY) * plotHeight)

            return CGPoint(x: x, y: y)
        }
    }
}

struct ProgressionBreakdownRow: View {
    let label: String
    let count: Int
    let percentage: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .caption(color: AppColors.textSecondary)
                Spacer()
                Text("\(count) (\(percentage)%)")
                    .caption(color: AppColors.textPrimary)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.surfaceTertiary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (CGFloat(percentage) / 100.0))
                }
            }
            .frame(height: 8)
        }
    }
}
