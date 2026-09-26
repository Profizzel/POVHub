import Foundation
import Vision
import CoreML
import CoreMedia
import SwiftData

// MARK: - MemoryTagModule - on-device, private, no cloud
// Daily use: "Where did I see my keys?"

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
        guard let modelURL = Bundle.main.url(forResource: "YOLOv3", withExtension: "mlmodelc") else {
            print("YOLOv3.mlmodelc not found - detection disabled, build still succeeds")
            return nil
        }
        do {
            let model = try MLModel(contentsOf: modelURL)
            return try VNCoreMLModel(for: model)
        } catch {
            print("Unable to load model: \(error)")
            return nil
        }
    }()
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func process(frame: CMSampleBuffer) async {
        guard isEnabled,
              let pixelBuffer = CMSampleBufferGetImageBuffer(frame),
              let objectModel else {
            return
        }

        let request = VNCoreMLRequest(model: objectModel) { [weak self] request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedObjectObservation],
                  let top = observations.filter({ $0.confidence > 0.7 }).max(by: { $0.confidence < $1.confidence }),
                  let label = top.labels.first?.identifier else {
                return
            }
            let usefulObjects = ["keys", "wallet", "cell phone", "laptop", "bottle", "cup", "backpack", "chair", "couch"]
            guard usefulObjects.contains(where: { label.localizedCaseInsensitiveContains($0) }) || top.confidence > 0.9 else {
                return
            }
            Task { @MainActor in
                POVLiveActivityManager.shared.updateLastSeen(object: label)
            }
            let tag = MemoryTag(objectLabel: label, timestamp: Date())
            self?.modelContext?.insert(tag)
            try? self?.modelContext?.save()
        }
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
