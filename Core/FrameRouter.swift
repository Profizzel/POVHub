import Foundation
import CoreMedia
import CoreVideo

// MARK: - FrameRouter - single source of truth
// DAT SDK or Mock delivers CMSampleBuffer, Router fans out only to enabled modules

protocol FrameConsumer: AnyObject {
    var moduleID: POVModuleID { get }
    var isEnabled: Bool { get set }
    func process(frame: CMSampleBuffer) async
}

final actor FrameRouter {
    static let shared = FrameRouter()
    private var consumers: [FrameConsumer] = []
    
    // Throttle: we don't need 30fps for Memory, 2fps is enough
    private var lastProcessTimes: [POVModuleID: Date] = [:]
    
    func register(_ consumer: FrameConsumer) {
        consumers.append(consumer)
    }
    
    func setEnabled(_ id: POVModuleID, enabled: Bool) {
        consumers.first(where: { $0.moduleID == id })?.isEnabled = enabled
    }
    
    // Called by StreamingCoreFacade on capture queue
    func route(_ sampleBuffer: CMSampleBuffer) async {
        for consumer in consumers where consumer.isEnabled {
            // Simple throttle per module
            let interval: TimeInterval = (consumer.moduleID == .safety) ? 0.1 : 0.5 // Safety 10fps, Memory 2fps
            let last = lastProcessTimes[consumer.moduleID] ?? .distantPast
            if Date().timeIntervalSince(last) >= interval {
                lastProcessTimes[consumer.moduleID] = Date()
                await consumer.process(frame: sampleBuffer)
            }
        }
    }
    
    func activeModuleIDs() -> [POVModuleID] {
        consumers.filter { $0.isEnabled }.map { $0.moduleID }
    }
}
