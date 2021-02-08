//
//  VisionBodyDetectionPresenter.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-02-06.
//

import Foundation
import Vision

protocol PresenterProtocol {
    func imagePoints(for results: [Any], frameWidth: CGFloat, frameHeight: CGFloat) -> [CGPoint]
}

protocol VisionHandlerProtocol {
    func setupVision(frameWidth: CGFloat, frameHeight: CGFloat, completion: @escaping ([CGPoint]?, VisionError?) -> ())
    func processBuffer(_ buffer: CVImageBuffer, orientation: CGImagePropertyOrientation)
}

enum VisionError: Swift.Error {
    case standard(description: String)
    case unknown
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
            let torsoKeys: [VNRecognizedPointKey] = [
                .bodyLandmarkKeyNose,
                .bodyLandmarkKeyLeftEye,
                .bodyLandmarkKeyRightEye,
                .bodyLandmarkKeyLeftEar,
                .bodyLandmarkKeyRightEar,
                .bodyLandmarkKeyLeftShoulder,
                .bodyLandmarkKeyRightShoulder,
                .bodyLandmarkKeyNeck,
                .bodyLandmarkKeyLeftElbow,
                .bodyLandmarkKeyRightElbow,
                .bodyLandmarkKeyLeftWrist,
                .bodyLandmarkKeyRightWrist,
                .bodyLandmarkKeyLeftHip,
                .bodyLandmarkKeyRightHip,
                .bodyLandmarkKeyRoot,
                .bodyLandmarkKeyLeftKnee,
                .bodyLandmarkKeyRightKnee,
                .bodyLandmarkKeyLeftAnkle,
                .bodyLandmarkKeyRightAnkle
            ]
            let imagePoints: [CGPoint] = torsoKeys.compactMap {
                guard let point = recognizedPoints[$0],
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
        let bodyRequest = VNDetectHumanBodyPoseRequest(completionHandler: { (request, error) in
            if let error = error {
                let visionError = VisionError.standard(description: error.localizedDescription)
                completion(nil, visionError)
                return
            }
            if let results = request.results {
                let imagePoints = self.imagePoints(for: results, frameWidth: frameWidth, frameHeight: frameHeight)
                completion(imagePoints, nil)
            }
        })
        requests = [bodyRequest]
    }

    func processBuffer(_ buffer: CVImageBuffer, orientation: CGImagePropertyOrientation) {
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: buffer,
                                                        orientation: orientation,
                                                        options: [:])
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }
}

