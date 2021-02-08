//
//  CameraController.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-01-30.
//

import UIKit
import AVFoundation
import Combine

enum VisionError: Swift.Error {
    case detection(_: Swift.Error)
}

enum AVCaptureError: Swift.Error {
    enum CameraError: Swift.Error {
        case cameraUnavailable
        case inputUnavailable
        case unableToLockConfiguration
    }
    case cameraError(_: CameraError)
    case visionError(_: VisionError)
    case captureSessionIsMissing
    case pixelbufferUnavailable
    case sessionUnableToAddInput
    case sessionUnableToAddOutput
    case videoOutputMissingConnection
    case unableToProcessBuffer(_: Swift.Error)
    case standard(_: Swift.Error)
}

class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var layerBounds: CGRect = .zero
    var videoDataOutput = AVCaptureVideoDataOutput()

    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput",
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)

    var bufferSize: CGSize = .zero

    let presenter = VisionBodyDetectionPresenter()

    var detectionPublisher: AnyPublisher<[CGPoint], AVCaptureError> {
        detectionSubject.eraseToAnyPublisher()
    }

    private let detectionSubject = PassthroughSubject<[CGPoint], AVCaptureError>()

    func prepare(_ completion: @escaping () -> Void) {
        do {
            try createCaptureSession()
        } catch let error {
            switch error {
            case let error as AVCaptureError:
                detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(error))
            default:
                let error = AVCaptureError.standard(error)
                detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(error))
            }
            completion()
            return
        }
        presenter.setupVision(frameWidth: bufferSize.width, frameHeight: bufferSize.height) { (cgPoints, visionError) in
            if let visionError = visionError {
                let error = AVCaptureError.visionError(visionError)
                self.detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(error))
            } else if let cgPoints = cgPoints,
                      !cgPoints.isEmpty {
                let adjustedPoints = self.adjustPoints(cgPoints, forBounds: self.layerBounds, bufferSize: self.bufferSize)
                self.detectionSubject.send(adjustedPoints)
            }
        }
        startCapture()
        completion()
    }

    private func adjustPoints( _ points: [CGPoint], forBounds bounds: CGRect, bufferSize: CGSize) -> [CGPoint] {
        var scale: CGFloat
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        return points.compactMap { cgPoint in
            let newX = cgPoint.y * scale
            let newY = cgPoint.x * scale
            return CGPoint(x: newX, y: newY)
        }
    }

    func createCaptureSession() throws {
        var deviceInput: AVCaptureDeviceInput!
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                 mediaType: .video,
                                                                 position: .back).devices.first else {
            throw AVCaptureError.cameraError(.cameraUnavailable)
        }
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            throw AVCaptureError.cameraError(.inputUnavailable)
        }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480 // Model image size is smaller.
        guard captureSession.canAddInput(deviceInput) else {
            print("Could not add video device input to the captureSession")
            captureSession.commitConfiguration()
            throw AVCaptureError.sessionUnableToAddInput
        }
        captureSession.addInput(deviceInput)
        guard captureSession.canAddOutput(videoDataOutput) else {
            print("Could not add video data output to the captureSession")
            captureSession.commitConfiguration()
            throw AVCaptureError.sessionUnableToAddOutput
        }
        captureSession.addOutput(videoDataOutput)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        guard let captureConnection = videoDataOutput.connection(with: .video) else {
            throw AVCaptureError.videoOutputMissingConnection
        }
        captureConnection.isEnabled = true
        do {
            try videoDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice.activeFormat.formatDescription))
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice.unlockForConfiguration()
        } catch {
            throw AVCaptureError.cameraError(.unableToLockConfiguration)
        }
        captureSession.commitConfiguration()
    }

    func startCapture() {
        captureSession.startRunning()
    }

    func displayPreview(on view: UIView) throws {
        guard captureSession.isRunning else {
            throw AVCaptureError.captureSessionIsMissing
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.connection?.videoOrientation = .portrait
        view.layer.insertSublayer(previewLayer!, at: 0)
        previewLayer?.frame = view.frame
        layerBounds = previewLayer?.bounds ?? .zero
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(.pixelbufferUnavailable))
            return
        }
        let exifOrientation = exifOrientationFromDeviceOrientation()
        do {
            try presenter.processBuffer(pixelBuffer, orientation: exifOrientation)
        } catch let error {
            detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(.unableToProcessBuffer(error)))
        }
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //
    }

    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}
