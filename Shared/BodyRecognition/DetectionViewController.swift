//
//  SwiftUICameraViewController.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-02-06.
//

import SwiftUI

struct DetectionViewController: UIViewControllerRepresentable {

    let pointViewModels: Binding<Array<PointViewModel>>
    let errorViewModel: Binding<AVCaptureError?>

    public func makeUIViewController(context: Context) -> CameraOutputViewController {
        let viewController = CameraOutputViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    public func updateUIViewController(_ uiViewController: CameraOutputViewController, context: Context) {
        //
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(pointViewModelsBinding: pointViewModels,
                    errorViewModelBinding: errorViewModel)
    }
}

// Coordinates SwiftUI/UIKit data binding
class Coordinator: CameraViewControllerDelegate {

    let pointViewModelsBinding: Binding<Array<PointViewModel>>
    let errorViewModelBinding: Binding<AVCaptureError?>

    init(pointViewModelsBinding: Binding<Array<PointViewModel>>,
         errorViewModelBinding: Binding<AVCaptureError?>) {
        self.pointViewModelsBinding = pointViewModelsBinding
        self.errorViewModelBinding = errorViewModelBinding
    }

    func updatedPointViewModels(_ pointViewModels: Array<PointViewModel>) {
        DispatchQueue.main.async {
            self.pointViewModelsBinding.wrappedValue = pointViewModels
        }
    }

    func receivedError(_ error: AVCaptureError) {
        DispatchQueue.main.async {
            self.errorViewModelBinding.wrappedValue = error
        }
    }
}
