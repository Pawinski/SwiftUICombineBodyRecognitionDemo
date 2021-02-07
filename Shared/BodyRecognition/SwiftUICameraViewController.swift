//
//  SwiftUICameraViewController.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-02-06.
//

import SwiftUI

struct SwiftUICameraViewController: UIViewControllerRepresentable {

    let pointViewModels: Binding<[PointViewModel]>

    public func makeUIViewController(context: Context) -> CameraViewController {
        let viewController = CameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    public func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        //
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(pointViewModelsBinding: pointViewModels)
    }
}

// Coordinates SwiftUI/UIKit data binding
class Coordinator: CameraViewControllerDelegate {

    let pointViewModelsBinding: Binding<[PointViewModel]>

    init(pointViewModelsBinding: Binding<[PointViewModel]>) {
        self.pointViewModelsBinding = pointViewModelsBinding
    }

    func updatedPointViewModels(_ viewController: CameraViewController, pointViewModels: [PointViewModel]) {
        pointViewModelsBinding.wrappedValue = pointViewModels
    }
}
