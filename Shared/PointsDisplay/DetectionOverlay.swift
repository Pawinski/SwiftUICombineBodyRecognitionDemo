//
//  DetectionOverlay.swift
//  SwiftUIBodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-02-06.
//

import SwiftUI

struct DetectionOverlay: View {

    @Binding var pointViewModels: [PointViewModel]
    @Binding var bufferSize: CGSize

    var body: some View {
        GeometryReader { geo in
            ForEach(pointViewModels, id: \.self) { pointViewModel in
                Circle()
                    .position(x: CGFloat(pointViewModel.x), y: CGFloat(pointViewModel.y))
                    .foregroundColor(.blue)
                    .frame(width: 30, height: 30, alignment: .center)
            }
            .position(x: 0, y: 0)
            .frame(width: bufferSize.width, height: bufferSize.height, alignment: .topLeading)
        }
    }
}
