//
//  ContentView.swift
//  Shared
//
//  Created by Alexander Pawinski on 2021-02-07.
//

import SwiftUI

class AppViewModel: ObservableObject {
    @Published var bufferSize: CGSize = CGSize(width: 640, height: 480)
    @Published var pointViewModels = [PointViewModel(x: 100, y: 100)]
    @Published var errorViewModel: AVCaptureError?
}

struct ContentView: View {

    @ObservedObject var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            DetectionViewController(pointViewModels: $appViewModel.pointViewModels,
                                    errorViewModel: $appViewModel.errorViewModel)
            if let error = appViewModel.errorViewModel {
                Text("Error: \(error.localizedDescription)")
            } else {
                DetectionOverlay(pointViewModels: $appViewModel.pointViewModels,
                                 bufferSize: $appViewModel.bufferSize)
                    .foregroundColor(.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .edgesIgnoringSafeArea(.top)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(appViewModel: AppViewModel())
    }
}
