import Foundation
import AVFoundation
import CoreMedia

// MARK: - SafetyCamModule - rolling buffer dashcam
// Daily use: auto-record when you leave home, lives in Island as REC

final class SafetyCamModule: FrameConsumer {
    let moduleID: POVModuleID = .safety
    var isEnabled: Bool = true // ON by default for v1
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isRecording = false
    private var outputURL: URL?
    
    func startRecording() {
        let fileName = "safety_\(Date().timeIntervalSince1970).mp4"
        let tempDir = FileManager.default.temporaryDirectory
        outputURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = outputURL else { return }
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1280,
                AVVideoHeightKey: 720
            ]
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            videoInput?.expectsMediaDataInRealTime = true
            
            if let input = videoInput, assetWriter?.canAdd(input) == true {
                assetWriter?.add(input)
            }
            
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            isRecording = true
            print("SafetyCam started: \(url)")
        } catch {
            print("SafetyCam failed: \(error)")
        }
    }
    
    func stopRecording() {
        isRecording = false
        videoInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            print("SafetyCam saved: \(self?.outputURL?.path ?? "")")
            // TODO: Move to Photos or keep 30-min rolling buffer (delete old)
        }
    }
    
    func process(frame: CMSampleBuffer) async {
        guard isEnabled, isRecording else { return }
        guard let input = videoInput, input.isReadyForMoreMediaData else { return }
        input.append(frame)
    }
}
