import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct CameraLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CameraActivityAttributes.self) { context in
            CameraLockScreenActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.12, green: 0.11, blue: 0.10))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    CameraActivityPhotoMosaic(
                        thumbnailIDs: context.state.thumbnailIDs,
                        singleRowBaseCellSize: 110,
                        multiRowCellSize: 53,
                        rowSpacing: 3
                    )
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                }
            } compactLeading: {
                CameraActivityThumbnail(
                    thumbnailID: context.state.thumbnailIDs.first,
                    cornerRadius: 5
                )
                .frame(width: 23, height: 23)
            } compactTrailing: {
                CameraActivityThumbnail(
                    thumbnailID: context.state.thumbnailIDs.dropFirst().first
                        ?? context.state.thumbnailIDs.first,
                    cornerRadius: 5
                )
                .frame(width: 23, height: 23)
            } minimal: {
                CameraActivityThumbnail(
                    thumbnailID: context.state.thumbnailIDs.first,
                    cornerRadius: 5
                )
                .frame(width: 23, height: 23)
            }
            .keylineTint(context.state.phase == .completed ? .green : .white)
        }
    }
}

private struct CameraLockScreenActivityView: View {
    let context: ActivityViewContext<CameraActivityAttributes>

    var body: some View {
        CameraActivityPhotoMosaic(
            thumbnailIDs: context.state.thumbnailIDs,
            singleRowBaseCellSize: 118,
            multiRowCellSize: 64,
            rowSpacing: 6
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct CameraActivityThumbnail: View {
    let thumbnailID: String?
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let image = loadThumbnail() {
                Image(uiImage: image.withRenderingMode(.alwaysOriginal))
                    .renderingMode(.original)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.90))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        }
        .clipped()
        .unredacted()
    }

    private func loadThumbnail() -> UIImage? {
        guard
            let thumbnailID,
            let url = CameraActivitySharedStorage.thumbnailURL(for: thumbnailID),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }

        return UIImage(data: data)?.withRenderingMode(.alwaysOriginal)
    }
}

private struct CameraActivityPhotoMosaic: View {
    let thumbnailIDs: [String]
    let singleRowBaseCellSize: CGFloat
    let multiRowCellSize: CGFloat
    let rowSpacing: CGFloat

    private var visibleIDs: [String] {
        Array(thumbnailIDs.prefix(8))
    }

    private var columnCount: Int {
        min(max(visibleIDs.count, 1), 4)
    }

    private var cellSize: CGFloat {
        switch visibleIDs.count {
        case 0, 1:
            singleRowBaseCellSize * 1.12
        case 2:
            singleRowBaseCellSize
        case 3:
            singleRowBaseCellSize * 0.82
        case 4:
            singleRowBaseCellSize * 0.72
        default:
            multiRowCellSize
        }
    }

    private var rows: [[String]] {
        stride(from: 0, to: visibleIDs.count, by: columnCount).map { start in
            Array(visibleIDs[start..<min(start + columnCount, visibleIDs.count)])
        }
    }

    private var contentWidth: CGFloat {
        let spacing = CGFloat(max(columnCount - 1, 0)) * 6
        return (CGFloat(columnCount) * cellSize) + spacing
    }

    var body: some View {
        Group {
            if visibleIDs.isEmpty {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                }
                .frame(width: cellSize, height: cellSize)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: rowSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 6) {
                            ForEach(row, id: \.self) { thumbnailID in
                                CameraActivityThumbnail(
                                    thumbnailID: thumbnailID,
                                    cornerRadius: min(16, cellSize * 0.18)
                                )
                                .frame(width: cellSize, height: cellSize)
                            }
                        }
                        .frame(width: contentWidth, alignment: .center)
                    }
                }
            }
        }
    }
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: CameraActivityAttributes(
    sessionID: "preview",
    contextTitle: "Our Baby's First Amusement Park Trip"
)) {
    CameraLiveActivityWidget()
} contentStates: {
    CameraActivityAttributes.ContentState(
        phase: .cameraActive,
        thumbnailIDs: [],
        selectedPhotoCount: 2,
        completedAt: nil
    )
    CameraActivityAttributes.ContentState(
        phase: .completed,
        thumbnailIDs: [],
        selectedPhotoCount: 2,
        completedAt: .now
    )
}
