//
//  CameraViewController.swift
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

final class CameraViewController: UIViewController {

    weak var delegate: CameraViewControllerDelegate?
    let cameraController = CameraController()
    var previewView: UIView!
    private var cancellables = [AnyCancellable]()

    override func viewDidLoad() {
        super.viewDidLoad()
        previewView = UIView(frame: CGRect(x: 0,
                                           y: 0,
                                           width: UIScreen.main.bounds.size.width,
                                           height: UIScreen.main.bounds.size.height))
        previewView.contentMode = .scaleAspectFit
        view.addSubview(previewView)
        cameraController.prepare {
            do {
                try self.cameraController.displayPreview(on: self.previewView)
            } catch {
                self.delegate?.receivedError(AVCaptureError.standard(error))
            }
        }
        cameraController.detectionPublisher
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
}
