//
//  ContentView.swift
//  Shared
//
//  Created by Alexander Pawinski on 2021-02-07.
//

import SwiftUI

struct ContentView: View {
    
    @State var pointViewModels: [PointViewModel] = []

    var body: some View {
        ZStack {
            SwiftUICameraViewController(pointViewModels: $pointViewModels)
                .edgesIgnoringSafeArea(.top)
            DetectionOverlay(pointViewModels: $pointViewModels)
                .edgesIgnoringSafeArea(.top)
                .foregroundColor(.clear)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
