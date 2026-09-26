import Foundation
import Vision
import CoreML
import CoreMedia
import SwiftData

@Model
final class MemoryTag {
    var id: UUID
    var objectLabel: String
    var timestamp: Date
    var locationDescription: String?
    var imageData: Data?
    init(objectLabel: String, timestamp: Date = Date(), locationDescription: String? = nil, imageData: Data? = nil) {
        self.id = UUID()
        self.objectLabel = objectLabel
        self.timestamp = timestamp
        self.locationDescription = locationDescription
        self.imageData = imageData
    }
}

final class MemoryTagModule: FrameConsumer {
    let moduleID: POVModuleID = .memory
    var isEnabled: Bool = true
    private var modelContext: ModelContext?
    
    private lazy var objectModel: VNCoreMLModel? = {
        // Try Tiny first (33MB), then full YOLOv3
        let candidates = ["YOLOv3Tiny", "YOLOv3"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                do {
                    let model = try MLModel(contentsOf: url)
                    print("Loaded \(name).mlmodelc")
                    return try VNCoreMLModel(for: model)
                } catch {
                    print("Failed to load \(name): \(error)")
                }
            }
        }
        print("No YOLO model found - MemoryTag will be disabled but build succeeds")
        return nil
    }()
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func process(frame: CMSampleBuffer) async {
        guard isEnabled, let pixelBuffer = CMSampleBufferGetImageBuffer(frame), let objectModel else { return }
        let request = VNCoreMLRequest(model: objectModel) { [weak self] request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedObjectObservation] else { return }
            let top = observations.filter { $0.confidence > 0.6 }.max { $0.confidence < $1.confidence }
            guard let best = top, let label = best.labels.first?.identifier else { return }
            let useful = ["keys", "wallet", "cell phone", "laptop", "bottle", "cup", "backpack", "chair", "couch", "book", "keyboard", "mouse"]
            if useful.contains(where: { label.localizedCaseInsensitiveContains($0) }) || best.confidence > 0.85 {
                Task { @MainActor in POVLiveActivityManager.shared.updateLastSeen(object: label) }
                let tag = MemoryTag(objectLabel: label, timestamp: Date())
                self?.modelContext?.insert(tag)
                try? self?.modelContext?.save()
            }
        }
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
