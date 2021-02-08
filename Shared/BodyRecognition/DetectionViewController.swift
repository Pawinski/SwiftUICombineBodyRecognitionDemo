//
//  SwiftUICameraViewController.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-02-06.
//

import SwiftUI

struct DetectionViewController: UIViewControllerRepresentable {

    let pointViewModels: Binding<[PointViewModel]>
    let errorViewModel: Binding<AVCaptureError?>

    public func makeUIViewController(context: Context) -> CameraViewController {
        let viewController = CameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    public func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        //
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(pointViewModelsBinding: pointViewModels, errorViewModelBinding: errorViewModel)
    }
}

// Coordinates SwiftUI/UIKit data binding
class Coordinator: CameraViewControllerDelegate {

    let pointViewModelsBinding: Binding<[PointViewModel]>
    let errorViewModelBinding: Binding<AVCaptureError?>

    init(pointViewModelsBinding: Binding<[PointViewModel]>,
         errorViewModelBinding: Binding<AVCaptureError?>) {
        self.pointViewModelsBinding = pointViewModelsBinding
        self.errorViewModelBinding = errorViewModelBinding
    }
    
    func updatedPointViewModels(_ pointViewModels: [PointViewModel]) {
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
