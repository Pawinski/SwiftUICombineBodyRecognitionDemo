//
//  VisionBodyDetectionPresenter.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-02-06.
//

import Vision

enum VisionError: Swift.Error {
    case detection(_: Swift.Error)
}

protocol PresenterProtocol {
    func imagePoints(for results: [Any], frameWidth: CGFloat, frameHeight: CGFloat) -> [CGPoint]
}

protocol VisionHandlerProtocol {
    func setupVision(frameWidth: CGFloat, frameHeight: CGFloat, completion: @escaping ([CGPoint]?, VisionError?) -> ())
    func processBuffer(_ buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) throws
}

class VisionBodyDetectionPresenter: PresenterProtocol, VisionHandlerProtocol {

    private var requests = [VNRequest]()

    func imagePoints(for results: [Any], frameWidth: CGFloat, frameHeight: CGFloat) -> [CGPoint] {
        var viewModels: [CGPoint] = []
        for observation in results where observation is VNRecognizedPointsObservation {
            guard let objectObservation = observation as? VNRecognizedPointsObservation else {
                continue
            }
            guard let recognizedPoints = try? objectObservation.recognizedPoints(forGroupKey: .all) else {
                continue
            }
            let torsoKeys: [VNHumanBodyPoseObservation.JointName] = [
                .nose,
                .leftEye,
                .rightEye,
                .leftEar,
                .rightEar,
                .leftShoulder,
                .rightShoulder,
                .neck,
                .leftElbow,
                .rightElbow,
                .leftWrist,
                .rightWrist,
                .leftHip,
                .rightHip,
                .root,
                .leftKnee,
                .rightKnee,
                .leftAnkle,
                .rightAnkle
            ]
            let imagePoints: [CGPoint] = torsoKeys.compactMap {
                guard let point = recognizedPoints[$0.rawValue],
                      point.confidence > 0.5 else {
                    return nil
                }
                return VNImagePointForNormalizedPoint(point.location,
                                                      Int(frameWidth),
                                                      Int(frameHeight))
            }
            viewModels.append(contentsOf: imagePoints)
        }
        return viewModels
    }

    func setupVision(frameWidth: CGFloat, frameHeight: CGFloat, completion:  @escaping ([CGPoint]?, VisionError?) -> ()) {
        let bodyRequest = VNDetectHumanBodyPoseRequest { request, error in
            if let error = error {
                let visionError = VisionError.detection(error)
                completion(nil, visionError)
                return
            }
            if let results = request.results {
                let imagePoints = self.imagePoints(for: results, frameWidth: frameWidth, frameHeight: frameHeight)
                completion(imagePoints, nil)
            }
        }
        requests = [bodyRequest]
    }

    func processBuffer(_ buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) throws {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            throw AVCaptureError.pixelbufferUnavailable
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                        orientation: orientation,
                                                        options: [:])
        do {
            try imageRequestHandler.perform(requests)
        } catch let error {
            throw error
        }
    }
}

