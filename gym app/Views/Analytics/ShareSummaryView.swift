//
//  ShareSummaryView.swift
//  gym app
//
//  Shareable analytics summary with format picker and image rendering.
//

import SwiftUI

enum ShareFormat: String, CaseIterable {
    case story = "Story"
    case square = "Square"

    var size: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}

struct ShareSummaryView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ShareFormat = .story
    @State private var showingShareSheet = false
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ShareFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.screenPadding)

                    // Preview
                    ShareSummaryCard(
                        format: selectedFormat,
                        timeRange: viewModel.selectedTimeRange,
                        workoutCount: viewModel.analyzedSessionCount,
                        totalVolume: viewModel.weeklyVolumeTrend.reduce(0) { $0 + $1.totalVolume },
                        prCount: viewModel.recentPRs.count,
                        topLiftName: viewModel.liftTrends.first?.exerciseName,
                        topLiftSet: viewModel.liftTrends.first?.latestTopSet.formatted,
                        currentE1RM: viewModel.selectedCurrentE1RM
                    )
                    .frame(
                        width: previewWidth,
                        height: previewWidth * (selectedFormat.size.height / selectedFormat.size.width)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                    Button {
                        renderAndShare()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.dominant)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Share Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = renderedImage {
                    ShareImageSheet(image: image)
                }
            }
        }
    }

    private var previewWidth: CGFloat {
        UIScreen.main.bounds.width - 64
    }

    private func renderAndShare() {
        let card = ShareSummaryCard(
            format: selectedFormat,
            timeRange: viewModel.selectedTimeRange,
            workoutCount: viewModel.analyzedSessionCount,
            totalVolume: viewModel.weeklyVolumeTrend.reduce(0) { $0 + $1.totalVolume },
            prCount: viewModel.recentPRs.count,
            topLiftName: viewModel.liftTrends.first?.exerciseName,
            topLiftSet: viewModel.liftTrends.first?.latestTopSet.formatted,
            currentE1RM: viewModel.selectedCurrentE1RM
        )
        .frame(width: selectedFormat.size.width, height: selectedFormat.size.height)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0
        if let image = renderer.uiImage {
            renderedImage = image
            showingShareSheet = true
        }
    }
}

// MARK: - Share Summary Card (rendered content)

private struct ShareSummaryCard: View {
    let format: ShareFormat
    let timeRange: AnalyticsTimeRange
    let workoutCount: Int
    let totalVolume: Double
    let prCount: Int
    let topLiftName: String?
    let topLiftSet: String?
    let currentE1RM: Double?

    var body: some View {
        ZStack {
            AppColors.background

            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: brandingIconSize, weight: .bold))
                        .foregroundColor(AppColors.dominant)

                    Text("GYM APP")
                        .font(.system(size: brandingTextSize, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(4)
                }

                Spacer()
                    .frame(height: sectionSpacing)

                // Time range
                Text(timeRangeLabel)
                    .font(.system(size: subtitleSize, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)

                Spacer()
                    .frame(height: sectionSpacing)

                // Stats
                statsContent

                // Top lift
                if let liftName = topLiftName, let liftSet = topLiftSet {
                    Spacer()
                        .frame(height: sectionSpacing)

                    VStack(spacing: 6) {
                        Text("Top Lift")
                            .font(.system(size: labelSize, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        Text(liftName)
                            .font(.system(size: statValueSize, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(liftSet)
                            .font(.system(size: subtitleSize, weight: .semibold))
                            .foregroundColor(AppColors.dominant)

                        if let e1rm = currentE1RM {
                            Text("e1RM: \(formatWeight(e1rm)) lbs")
                                .font(.system(size: labelSize, weight: .medium))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }

                Spacer()

                // Bottom gradient bar
                LinearGradient(
                    colors: [AppColors.dominant, AppColors.accent2],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: accentBarHeight)
            }
            .padding(contentPadding)
        }
    }

    @ViewBuilder
    private var statsContent: some View {
        if format == .square {
            // 2x2 grid for square
            VStack(spacing: gridSpacing) {
                HStack(spacing: gridSpacing) {
                    statTile(label: "Workouts", value: "\(workoutCount)")
                    statTile(label: "Total Volume", value: "\(formatVolume(totalVolume)) lbs")
                }
                HStack(spacing: gridSpacing) {
                    statTile(label: "PRs", value: "\(prCount)")
                    statTile(label: "e1RM", value: currentE1RM.map { "\(formatWeight($0))" } ?? "--")
                }
            }
        } else {
            // Vertical stack for story
            VStack(spacing: gridSpacing) {
                statTile(label: "Workouts", value: "\(workoutCount)")
                statTile(label: "Total Volume", value: "\(formatVolume(totalVolume)) lbs")
                statTile(label: "PRs Hit", value: "\(prCount)")
            }
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: statValueSize, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.dominant)
            Text(label)
                .font(.system(size: labelSize, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, tilePadding)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surfacePrimary)
        )
    }

    private var timeRangeLabel: String {
        switch timeRange {
        case .month: return "Last 28 Days"
        case .quarter: return "Last 90 Days"
        case .allTime: return "All Time"
        }
    }

    // MARK: - Dynamic sizing based on format

    private var brandingIconSize: CGFloat { format == .square ? 40 : 48 }
    private var brandingTextSize: CGFloat { format == .square ? 28 : 36 }
    private var subtitleSize: CGFloat { format == .square ? 18 : 22 }
    private var statValueSize: CGFloat { format == .square ? 28 : 36 }
    private var labelSize: CGFloat { format == .square ? 14 : 18 }
    private var sectionSpacing: CGFloat { format == .square ? 24 : 40 }
    private var gridSpacing: CGFloat { format == .square ? 12 : 16 }
    private var contentPadding: CGFloat { format == .square ? 32 : 48 }
    private var tilePadding: CGFloat { format == .square ? 16 : 20 }
    private var accentBarHeight: CGFloat { format == .square ? 6 : 8 }
}

// MARK: - Share Sheet

private struct ShareImageSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
