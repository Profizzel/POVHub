import SwiftUI
import SwiftData
import UIKit

// MARK: - Main App - Toggle Hub

struct ContentView: View {
    @StateObject private var liveManager = POVLiveActivityManager.shared
    @Environment(\.modelContext) private var modelContext
    
    @State private var memoryEnabled = true
    @State private var safetyEnabled = true
    @State private var shareEnabled = false
    @State private var isSessionActive = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Active Session") {
                    HStack {
                        if isSessionActive {
                            Circle().fill(Color.red).frame(width: 10, height: 10)
                            Text("LIVE • \(formatDuration(liveManager.currentState?.durationSeconds ?? 0))")
                                .font(.headline)
                                .foregroundColor(.red)
                        } else {
                            Circle().fill(Color.gray).frame(width: 10, height: 10)
                            Text("Not Live")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(isSessionActive ? "END" : "START") {
                            Task {
                                if isSessionActive {
                                    await liveManager.endSession()
                                    StreamingCoreFacade.shared.stop()
                                    isSessionActive = false
                                } else {
                                    liveManager.startSession()
                                    StreamingCoreFacade.shared.startMockStream() // Free test
                                    // Register modules
                                    let memory = MemoryTagModule()
                                    memory.setModelContext(modelContext)
                                    memory.isEnabled = memoryEnabled
                                    await FrameRouter.shared.register(memory)
                                    
                                    let safety = SafetyCamModule()
                                    safety.isEnabled = safetyEnabled
                                    if safetyEnabled { safety.startRecording() }
                                    await FrameRouter.shared.register(safety)
                                    
                                    isSessionActive = true
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(isSessionActive ? .red : .green)
                    }
                    
                    if let thumbData = liveManager.currentState?.thumbnailData,
                       let uiImage = UIImage(data: thumbData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    }
                    
                    if let last = liveManager.currentState?.lastSeenObject {
                        Text("Last seen: \(last)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Island Modules - Toggle what you want live") {
                    ToggleRow(icon: "brain", name: "Memory Tag", subtitle: "Where did I see my keys?", isOn: $memoryEnabled)
                    ToggleRow(icon: "video.fill", name: "Safety Cam", subtitle: "Rolling dashcam buffer", isOn: $safetyEnabled)
                    ToggleRow(icon: "person.2.fill", name: "Live Share", subtitle: "Let friends see your POV (needs LiveKit)", isOn: $shareEnabled)
                    ToggleRow(icon: "translate", name: "Live Translate", subtitle: "Coming soon", isOn: .constant(false))
                        .disabled(true)
                    ToggleRow(icon: "checklist", name: "Inspector", subtitle: "Coming soon", isOn: .constant(false))
                        .disabled(true)
                }
                
                Section("How to test FREE") {
                    Text("1. Run on iPhone with Personal Team\n2. Mock uses iPhone camera as glasses\n3. Island shows thumbnail + REC\n4. Memory saves objects to SwiftData\n5. No paywall, local only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Recent Memories") {
                    MemoryListView()
                }
            }
            .navigationTitle("POV Hub")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: memoryEnabled) { _, new in
            Task { await FrameRouter.shared.setEnabled(.memory, enabled: new) }
            liveManager.updateActiveModules(activeModulesList())
        }
        .onChange(of: safetyEnabled) { _, new in
            Task { await FrameRouter.shared.setEnabled(.safety, enabled: new) }
            liveManager.updateActiveModules(activeModulesList())
        }
    }
    
    private func activeModulesList() -> [String] {
        var mods: [String] = []
        if memoryEnabled { mods.append("Memory") }
        if safetyEnabled { mods.append("Safety") }
        if shareEnabled { mods.append("Share") }
        return mods
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct ToggleRow: View {
    var icon: String
    var name: String
    var subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .background(isOn ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(6)
            VStack(alignment: .leading) {
                Text(name).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
    }
}

struct MemoryListView: View {
    @Query(sort: \MemoryTag.timestamp, order: .reverse) var memories: [MemoryTag]
    
    var body: some View {
        ForEach(memories.prefix(5)) { mem in
            HStack {
                Text(mem.objectLabel).font(.caption.bold())
                Spacer()
                Text(mem.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
            }
        }
    }
}
