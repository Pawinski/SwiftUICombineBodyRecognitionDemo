//
//  AVCaptureViewModel.swift
//  SwiftUICombineBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-02-19.
//

import AVFoundation

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

class AVCaptureViewModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private struct Constants {
        static let videoDataOutputQueueLabel = "VideoDataOutput"
    }
    private let captureSession = AVCaptureSession()
    private let videoDataOutputQueue = DispatchQueue(label: Constants.videoDataOutputQueueLabel,
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)
    private var previewLayer: AVCaptureVideoPreviewLayer?

    var bufferSize: Result<CGSize, Error> {
        get {
            do {
                let videoDevice = try getCaptureDevice()
                try videoDevice.lockForConfiguration()
                let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice.activeFormat.formatDescription))
                videoDevice.unlockForConfiguration()
                return Result.success(CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height)))
            } catch {
                return Result.failure(error)
            }
        }
    }
    var previewLayerBounds: CGRect {
        get {
            previewLayer?.bounds ?? .zero
        }
    }
    var bufferHandler: ((CMSampleBuffer) -> Void)?

    func bind(bufferHandler: @escaping (CMSampleBuffer) -> Void) {
        self.bufferHandler = bufferHandler
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        bufferHandler?(sampleBuffer)
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //
    }

    // TODO: How to handle delegation?
    func getPreviewLayer() throws -> AVCaptureVideoPreviewLayer {
        guard isCaptureSessionRunning else {
            throw AVCaptureError.captureSessionIsMissing
        }
        let session = try getCaptureSession()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer
        return previewLayer
    }

    private func getVideoDataOutput() -> AVCaptureVideoDataOutput {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        return videoDataOutput
    }

    private func getCaptureSession() throws -> AVCaptureSession {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480 // Model image size is smaller.
        do {
            try setupInput()
            try setupOutput()
        } catch {
            throw error
        }
        captureSession.commitConfiguration()
        return captureSession
    }

    func startCaptureSession() {
        captureSession.startRunning()
    }

    private var isCaptureSessionRunning: Bool {
        captureSession.isRunning
    }

    private func getCaptureDevice() throws -> AVCaptureDevice {
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                 mediaType: .video,
                                                                 position: .back).devices.first else {
            throw AVCaptureError.cameraError(.cameraUnavailable)
        }
        return videoDevice
    }

    private func getDeviceInput(from device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        do {
            return try AVCaptureDeviceInput(device: device)
        } catch {
            throw error
        }
    }

    private func setupInput() throws {
        let videoDevice = try getCaptureDevice()
        let deviceInput = try getDeviceInput(from: videoDevice)
        guard captureSession.canAddInput(deviceInput) else {
            print("Could not add video device input to the captureSession")
            captureSession.commitConfiguration()
            throw AVCaptureError.sessionUnableToAddInput
        }
        captureSession.addInput(deviceInput)
    }

    private func setupOutput() throws {
        let videoDataOutput = getVideoDataOutput()
        guard captureSession.canAddOutput(videoDataOutput) else {
            print("Could not add video data output to the captureSession")
            captureSession.commitConfiguration()
            throw AVCaptureError.sessionUnableToAddOutput
        }
        captureSession.addOutput(videoDataOutput)
        guard let captureConnection = videoDataOutput.connection(with: .video) else {
            throw AVCaptureError.videoOutputMissingConnection
        }
        captureConnection.isEnabled = true
    }
}
