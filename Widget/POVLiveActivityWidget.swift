import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Dynamic Island UI - Remember & Record

struct POVLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: POVAttributes.self) { context in
            // Lock Screen
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatDuration(context.state.durationSeconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    if let data = context.state.thumbnailData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 60)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        ForEach(context.state.activeModules, id: \.self) { mod in
                            Text(mod)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(4)
                        }
                        if let last = context.state.lastSeenObject {
                            Text(last)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                        if context.state.isLEDOn {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.caption2.bold())
                }
            } compactTrailing: {
                Text(formatDuration(context.state.durationSeconds))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Circle().fill(Color.red).frame(width: 8, height: 8)
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<POVAttributes>
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("POV Hub • \(context.attributes.glassesModel)")
                        .font(.caption.bold())
                }
                if let last = context.state.lastSeenObject {
                    Text("Last seen: \(last)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text("\(context.state.activeModules.joined(separator: " • "))")
                    .font(.caption2)
            }
            Spacer()
            if let data = context.state.thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 40)
                    .clipped()
                    .cornerRadius(6)
            }
            Text(formatDuration(context.state.durationSeconds))
                .font(.headline.monospacedDigit())
        }
        .padding()
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
