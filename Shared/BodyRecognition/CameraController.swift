//
//  CameraController.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-01-30.
//

import UIKit
import AVFoundation
import Combine

enum AVCaptureError: Swift.Error {
    case cameraInputUnavailable
    case cameraUnavailable
    case cameraUnableToLockConfiguration
    case captureSessionIsMissing
    case sessionUnableToAddInput
    case sessionUnableToAddOutput
    case videoOutputMissingConnection
    case unknown
    case combine(description:String)
}

class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var videoDataOutput = AVCaptureVideoDataOutput()

    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput",
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)

    var bufferSize: CGSize = .zero

    let presenter = VisionBodyDetectionPresenter()

    var detectionPublisher: AnyPublisher<[CGPoint], Never> {
        detectionSubject.eraseToAnyPublisher()
    }

    private let detectionSubject = PassthroughSubject<[CGPoint], Never>()

    func prepare(completionHandler: @escaping (Error?) -> Void) {
        do {
            try self.createCaptureSession()
        } catch {
            completionHandler(error)
            return
        }
        presenter.setupVision(frameWidth: bufferSize.width, frameHeight: bufferSize.height) {
            self.detectionSubject.send($0)
        }
        startCapture()
        completionHandler(nil)
    }

    func createCaptureSession() throws {
        var deviceInput: AVCaptureDeviceInput!
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                 mediaType: .video,
                                                                 position: .back).devices.first else {
            throw AVCaptureError.cameraUnavailable
        }
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            throw AVCaptureError.cameraInputUnavailable
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
            throw AVCaptureError.cameraUnableToLockConfiguration
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
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let exifOrientation = exifOrientationFromDeviceOrientation()
        presenter.processBuffer(pixelBuffer, orientation: exifOrientation)
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
