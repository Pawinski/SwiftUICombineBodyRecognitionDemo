//
//  DetectionOverlay.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-02-06.
//

import SwiftUI

struct DetectionOverlay: View {

    @Binding var pointViewModels: [PointViewModel]

    var body: some View {
        ForEach(pointViewModels, id: \.self) { pointViewModel in
            Circle()
                .position(x: CGFloat(pointViewModel.x), y: CGFloat(pointViewModel.y))
                .foregroundColor(.blue)
                .frame(width: 30, height: 30, alignment: .center)
        }
    }
}
