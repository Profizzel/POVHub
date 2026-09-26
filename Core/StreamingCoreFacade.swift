import Foundation
import AVFoundation
import CoreMedia
import CoreImage

// MARK: - StreamingCoreFacade - Mock + Real DAT path + iPhone camera fallback
// This lets you test locally FREE without glasses or DAT approval

enum StreamingSource {
    case mock
    case iPhoneCamera
    case realGlasses // Requires DAT SDK: https://github.com/facebook/meta-wearables-dat-ios
}

final class StreamingCoreFacade: NSObject {
    static let shared = StreamingCoreFacade()
    
    var useMock = true // Flip to false when you have DAT + glasses
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "povhub.capture", qos: .userInitiated)
    
    // Mock: replay video file as CMSampleBuffer
    func startMockStream() {
        // For v1, we use iPhone camera as mock if no video file
        startiPhoneCamera()
    }
    
    func startiPhoneCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .hd1280x720
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        captureSession?.addInput(input)
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        videoOutput?.setSampleBufferDelegate(self, queue: captureQueue)
        
        if let output = videoOutput {
            captureSession?.addOutput(output)
        }
        
        captureQueue.async { [weak self] in
            self?.captureSession?.startRunning()
            print("Camera started running")
        }
        
        Task { @MainActor in
            POVLiveActivityManager.shared.updateStatus(.live)
        }
    }
    
    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        Task { @MainActor in
            POVLiveActivityManager.shared.updateStatus(.paused)
        }
    }
    
    // TODO: Real DAT integration
    // 1. Add SPM: https://github.com/facebook/meta-wearables-dat-ios
    // 2. import MetaWearablesDAT
    // 3. Implement DATSessionDelegate -> didReceiveVideoSampleBuffer -> FrameRouter.shared.route(buffer)
}

extension StreamingCoreFacade: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task {
            await FrameRouter.shared.route(sampleBuffer)
            await ThumbnailGenerator.shared.update(from: sampleBuffer)
        }
    }
}

// MARK: - Thumbnail generator for Live Activity (tiny JPEG)

actor ThumbnailGenerator {
    static let shared = ThumbnailGenerator()
    private var lastUpdate = Date.distantPast
    
    func update(from sampleBuffer: CMSampleBuffer) async {
        // Throttle thumbnail to 1 per second for Island
        guard Date().timeIntervalSince(lastUpdate) > 1.0 else { return }
        lastUpdate = Date()
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        // Downscale to 120x90
        let targetSize = CGSize(width: 120, height: 90)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let resized = cgImage // For brevity, use original in v1, downscale in v2 with vImage
        
        // Convert to JPEG 0.4 quality
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return }
        let props = [kCGImageDestinationLossyCompressionQuality: 0.4] as [CFString: Any]
        CGImageDestinationAddImage(dest, resized, props as CFDictionary)
        CGImageDestinationFinalize(dest)
        
        await POVLiveActivityManager.shared.updateThumbnail(data as Data)
    }
}
