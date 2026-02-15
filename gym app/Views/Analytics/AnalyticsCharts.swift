//
//  AnalyticsCharts.swift
//  gym app
//
//  Analytics chart and chart-row views.
//

import SwiftUI
import Charts

struct E1RMSwiftChart: View {
    let points: [E1RMProgressPoint]
    @State private var selectedPoint: E1RMProgressPoint?

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.estimatedOneRepMax)
        let minVal = (values.min() ?? 0) - 5
        let maxVal = (values.max() ?? 1) + 5
        return minVal...maxVal
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", point.estimatedOneRepMax)
                )
                .foregroundStyle(AppColors.dominant)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", point.estimatedOneRepMax)
                )
                .foregroundStyle(point.id == points.last?.id ? AppColors.warning : AppColors.dominant)
                .symbolSize(point.id == points.last?.id ? 50 : 30)
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(AppColors.textTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatMonthDay(date))
                    }
                }
                .foregroundStyle(AppColors.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatWeight(v))
                    }
                }
                .foregroundStyle(AppColors.textTertiary)
                AxisGridLine()
                    .foregroundStyle(AppColors.surfaceTertiary.opacity(0.5))
            }
        }
        .chartBackground { _ in AppColors.surfaceSecondary }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let plotFrame = proxy.plotFrame {
                                    let x = value.location.x - geo[plotFrame].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedPoint = closestPoint(to: date)
                                    }
                                }
                            }
                            .onEnded { _ in selectedPoint = nil }
                    )
            }
        }
        .overlay(alignment: .top) {
            if let selected = selectedPoint {
                tooltipView(for: selected)
            }
        }
    }

    private func closestPoint(to date: Date) -> E1RMProgressPoint? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func tooltipView(for point: E1RMProgressPoint) -> some View {
        VStack(spacing: 2) {
            Text(formatMonthDay(point.date))
                .caption(color: AppColors.textTertiary)
            Text("\(formatWeight(point.estimatedOneRepMax)) lbs")
                .caption(color: AppColors.textPrimary)
                .fontWeight(.semibold)
            Text(point.topSet.formatted)
                .caption(color: AppColors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(AppColors.surfaceSecondary)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
        .padding(.top, 4)
    }
}

struct VolumeTrendSwiftChart: View {
    let points: [WeeklyVolumePoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Week", point.weekStart, unit: .weekOfYear),
                y: .value("Volume", point.totalVolume)
            )
            .foregroundStyle(point.totalVolume > 0 ? AppColors.dominant : AppColors.surfaceTertiary)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 2)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatMonthDay(date))
                    }
                }
                .foregroundStyle(AppColors.textTertiary)
            }
        }
        .chartYAxis(.hidden)
        .chartBackground { _ in Color.clear }
    }
}

struct MuscleBalanceBar: View {
    let item: MuscleGroupVolume
    var maxPercentage: Double = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.muscleGroup)
                    .caption(color: AppColors.textSecondary)
                Spacer()
                Text("\(Int(item.percentageOfTotal))% \u{00B7} \(formatVolume(item.totalVolume)) lbs")
                    .caption(color: AppColors.textPrimary)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.surfaceTertiary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.percentageOfTotal < 10 ? AppColors.warning : AppColors.dominant)
                        .frame(width: geometry.size.width * CGFloat(item.percentageOfTotal / max(maxPercentage, 1)))
                }
            }
            .frame(height: 8)
        }
    }
}

struct WeeklyCardioSwiftChart: View {
    let points: [WeeklyCardioPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Week", point.weekStart, unit: .weekOfYear),
                y: .value("Duration", Double(point.totalDuration) / 60.0)
            )
            .foregroundStyle(point.totalDuration > 0 ? AppColors.accent2 : AppColors.surfaceTertiary)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 2)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatMonthDay(date))
                    }
                }
                .foregroundStyle(AppColors.textTertiary)
            }
        }
        .chartYAxis(.hidden)
        .chartBackground { _ in Color.clear }
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
