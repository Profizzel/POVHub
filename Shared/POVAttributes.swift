import ActivityKit
import Foundation

// MARK: - Shared model, must be included in BOTH App target and Widget Extension target
// Keep ContentState < 4KB total - thumbnail must be tiny JPEG ~2.5KB

struct POVAttributes: ActivityAttributes {
    // Static - set once at request time
    var sessionId: String
    var glassesModel: String // "Ray-Ban Meta Gen 1" or "Mock"
    
    public struct ContentState: Codable, Hashable {
        var status: StreamStatus
        var activeModules: [String] // e.g. ["Memory", "Safety"]
        var viewerCount: Int
        var durationSeconds: Int
        var isLEDOn: Bool
        var lastSeenObject: String? // "keys • couch"
        var lastSeenTimestamp: Date?
        var startedAt: Date
        var thumbnailData: Data? // 120x90 JPEG @ 0.4 quality
        
        // Helper
        var isRecording: Bool { activeModules.contains("Safety") }
        var isRemembering: Bool { activeModules.contains("Memory") }
    }
}

enum StreamStatus: String, Codable, Hashable {
    case connecting
    case live
    case paused
    case error
}

enum POVModuleID: String, Codable, CaseIterable {
    case memory = "Memory"
    case safety = "Safety"
    case liveShare = "Share"
    case translate = "Translate"
    case inspector = "Inspector"
}
