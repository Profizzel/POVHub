import ActivityKit
import Foundation

@MainActor
final class POVLiveActivityManager: ObservableObject {
    static let shared = POVLiveActivityManager()
    private var activity: Activity<POVAttributes>?
    @Published var currentState: POVAttributes.ContentState?
    
    func startSession() {
        let attributes = POVAttributes(sessionId: UUID().uuidString, glassesModel: "iPhone Cam")
        let state = POVAttributes.ContentState(
            status: .live,
            activeModules: ["Memory", "Safety"],
            viewerCount: 0,
            durationSeconds: 0,
            isLEDOn: true,
            lastSeenObject: nil,
            lastSeenTimestamp: nil,
            startedAt: Date(),
            thumbnailData: nil
        )
        // Always set state + timer so UI works even if Live Activity permission off
        currentState = state
        startDurationTimer()
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities disabled in Settings - in-app timer still runs")
            return
        }
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("POV Live Activity started: \(activity?.id ?? "")")
        } catch {
            print("Live Activity failed (ok for free team): \(error) - in-app timer continues")
        }
    }
    
    func updateStatus(_ status: StreamStatus) {
        var newState = currentState
        newState?.status = status
        Task { await self.update(state: newState) }
    }
    func updateThumbnail(_ data: Data) {
        var newState = currentState
        newState?.thumbnailData = data
        Task { await self.update(state: newState) }
    }
    func updateLastSeen(object: String) {
        var newState = currentState
        newState?.lastSeenObject = object
        newState?.lastSeenTimestamp = Date()
        Task { await self.update(state: newState) }
    }
    func updateActiveModules(_ modules: [String]) {
        var newState = currentState
        newState?.activeModules = modules
        Task { await self.update(state: newState) }
    }
    private func update(state: POVAttributes.ContentState?) async {
        guard let state = state else { return }
        currentState = state
        if let act = activity {
            await act.update(.init(state: state, staleDate: nil))
        }
    }
    func endSession() async {
        durationTask?.cancel()
        durationTask = nil
        let finalState = currentState
        if let act = activity {
            await act.end(.init(state: finalState ?? .init(status: .paused, activeModules: [], viewerCount: 0, durationSeconds: 0, isLEDOn: false, lastSeenObject: nil, lastSeenTimestamp: nil, startedAt: Date(), thumbnailData: nil), staleDate: nil), dismissalPolicy: .immediate)
        }
        activity = nil
        currentState = nil
    }
    // Use Task loop instead of Timer - more reliable
    private var durationTask: Task<Void, Never>?
    private func startDurationTimer() {
        durationTask?.cancel()
        durationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard var state = self.currentState else { continue }
                state.durationSeconds = Int(Date().timeIntervalSince(state.startedAt))
                if state.durationSeconds >= 8*3600 {
                    await self.endSession()
                    return
                }
                self.currentState = state
                if let act = self.activity {
                    await act.update(.init(state: state, staleDate: nil))
                }
            }
        }
    }
}
extension POVAttributes.ContentState {
    init(status: StreamStatus) {
        self.init(status: status, activeModules: [], viewerCount: 0, durationSeconds: 0, isLEDOn: false, lastSeenObject: nil, lastSeenTimestamp: nil, startedAt: Date(), thumbnailData: nil)
    }
}
