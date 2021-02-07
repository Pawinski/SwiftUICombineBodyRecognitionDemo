//
//  CameraViewController.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-01-30.
//

import UIKit
import Combine

protocol CameraViewControllerDelegate: AnyObject {
    func updatedPointViewModels(_ viewController: CameraViewController, pointViewModels: [PointViewModel])
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
        cameraController.prepare { error in
            if let error = error {
                print(error)
            }
            try? self.cameraController.displayPreview(on: self.previewView)
        }
        cameraController.detectionPublisher
            .removeDuplicates()
            .sink { points in
                let pointViewModels = points.compactMap { PointViewModel(x: Float($0.x), y: Float($0.y)) }
                self.delegate?.updatedPointViewModels(self, pointViewModels: pointViewModels)
            }.store(in: &cancellables)
    }
}
