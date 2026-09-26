import ActivityKit
import Foundation

// MARK: - POVLiveActivityManager - owns the Dynamic Island

@MainActor
final class POVLiveActivityManager: ObservableObject {
    static let shared = POVLiveActivityManager()
    
    private var activity: Activity<POVAttributes>?
    @Published var currentState: POVAttributes.ContentState?
    
    func startSession() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        let attributes = POVAttributes(sessionId: UUID().uuidString, glassesModel: "Mock iPhone Cam")
        let state = POVAttributes.ContentState(
            status: .connecting,
            activeModules: ["Memory", "Safety"],
            viewerCount: 0,
            durationSeconds: 0,
            isLEDOn: true,
            lastSeenObject: nil,
            lastSeenTimestamp: nil,
            startedAt: Date(),
            thumbnailData: nil
        )
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil // LOCAL only, free team works
            )
            currentState = state
            startDurationTimer()
            print("POV Live Activity started: \(activity?.id ?? "")")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updateStatus(_ status: StreamStatus) {
        Task {
            var newState = currentState
            newState?.status = status
            await update(state: newState)
        }
    }
    
    func updateThumbnail(_ data: Data) {
        Task {
            var newState = currentState
            newState?.thumbnailData = data
            await update(state: newState)
        }
    }
    
    func updateLastSeen(object: String) {
        Task {
            var newState = currentState
            newState?.lastSeenObject = object
            newState?.lastSeenTimestamp = Date()
            await update(state: newState)
        }
    }
    
    func updateActiveModules(_ modules: [String]) {
        Task {
            var newState = currentState
            newState?.activeModules = modules
            await update(state: newState)
        }
    }
    
    private func update(state: POVAttributes.ContentState?) async {
        guard let state = state else { return }
        currentState = state
        await activity?.update(.init(state: state, staleDate: nil))
    }
    
    func endSession() async {
        let finalState = currentState
        await activity?.end(.init(state: finalState ?? .init(status: .paused, activeModules: [], viewerCount: 0, durationSeconds: 0, isLEDOn: false, lastSeenObject: nil, lastSeenTimestamp: nil, startedAt: Date(), thumbnailData: nil), staleDate: nil), dismissalPolicy: .immediate)
        activity = nil
        durationTimer?.invalidate()
    }
    
    // MARK: - Duration timer
    private var durationTimer: Timer?
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard var state = self.currentState else { return }
                state.durationSeconds = Int(Date().timeIntervalSince(state.startedAt))
                
                // Auto-end at 8 hours (Apple limit)
                if state.durationSeconds >= 8 * 3600 {
                    await self.endSession()
                    return
                }
                
                await self.update(state: state)
            }
        }
    }
}

// Default ContentState for easy init
extension POVAttributes.ContentState {
    init(status: StreamStatus) {
        self.init(status: status, activeModules: [], viewerCount: 0, durationSeconds: 0, isLEDOn: false, lastSeenObject: nil, lastSeenTimestamp: nil, startedAt: Date(), thumbnailData: nil)
    }
}
