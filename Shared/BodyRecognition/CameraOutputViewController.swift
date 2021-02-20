//
//  CameraOutputViewController.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-01-30.
//

import UIKit
import Combine

protocol CameraViewControllerDelegate: AnyObject {
    func updatedPointViewModels(_ pointViewModels: Array<PointViewModel>)
    func receivedError(_ error: AVCaptureError)
}

final class CameraOutputViewController: UIViewController {

    weak var delegate: CameraViewControllerDelegate?

    private let avCaptureViewModel = AVCaptureViewModel()
    private let presenter = VisionBodyDetectionPresenter()

    var detectionPublisher: AnyPublisher<[CGPoint], AVCaptureError> {
        detectionSubject.eraseToAnyPublisher()
    }
    private let detectionSubject = PassthroughSubject<[CGPoint], AVCaptureError>()
    private var cancellables = [AnyCancellable]()

    override func viewDidLoad() {
        super.viewDidLoad()
        let previewView = UIView(frame: CGRect(x: 0,
                                           y: 0,
                                           width: UIScreen.main.bounds.size.width,
                                           height: UIScreen.main.bounds.size.height))
        previewView.contentMode = .scaleAspectFit
        view.addSubview(previewView)
        setupListeners()
        do {
            try self.displayPreview(on: previewView)
        } catch {
            self.delegate?.receivedError(AVCaptureError.standard(error))
        }
        setupPublisher()
    }

    private func setupListeners() {
        avCaptureViewModel.bind { sampleBuffer in
            let exifOrientation = self.exifOrientationFromDeviceOrientation()
            do {
                try self.presenter.processBuffer(sampleBuffer, orientation: exifOrientation)
            } catch let error {
                self.detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(.unableToProcessBuffer(error)))
            }
        }
        switch avCaptureViewModel.bufferSize {
        case .success(let bufferSize):
            presenter.setupVision(frameWidth: bufferSize.width, frameHeight: bufferSize.height) { (cgPoints, visionError) in
                if let visionError = visionError {
                    let error = AVCaptureError.visionError(visionError)
                    self.detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(error))
                } else if let cgPoints = cgPoints,
                          !cgPoints.isEmpty {
                    let adjustedPoints = self.adjustPoints(cgPoints,
                                                           forBounds: self.avCaptureViewModel.previewLayerBounds,
                                                           bufferSize: bufferSize)
                    self.detectionSubject.send(adjustedPoints)
                }
            }
            startCapture()
        case .failure(let error):
            switch error {
            case let error as AVCaptureError:
                detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(error))
            default:
                let error = AVCaptureError.standard(error)
                detectionSubject.send(completion: Subscribers.Completion<AVCaptureError>.failure(error))
            }
        }
    }

    private func setupPublisher() {
        detectionPublisher
            .removeDuplicates()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.delegate?.receivedError(error)
                case .finished:
                    return
                }
            },
            receiveValue: { points in
                let pointViewModels = points.compactMap { PointViewModel(x: Float($0.x), y: Float($0.y)) }
                self.delegate?.updatedPointViewModels(pointViewModels)
            })
            .store(in: &cancellables)
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

    private func startCapture() {
        avCaptureViewModel.startCaptureSession()
    }

    private func displayPreview(on view: UIView) throws {
        do {
            let previewLayer = try avCaptureViewModel.getPreviewLayer()
            view.layer.insertSublayer(previewLayer, at: 0)
            previewLayer.frame = view.frame
        } catch {
            throw error
        }
    }

    private func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
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
