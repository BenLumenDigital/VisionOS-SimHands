//
//  ContentView.swift
//  HandsTest
//
//  Created by Ben Harraway on 15/12/2023.
//

import SwiftUI
import RealityKit


struct ContentView: View {
    @State private var currentStyle: ImmersionStyle = .mixed
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @State private var openedImmersiveSpace = false
    
    var body: some View {
        VStack {
            Button("Start Sim Hands") {
                openedImmersiveSpace = true
                Task {
                    await openImmersiveSpace(id: "ImmersiveSpace")
                }
            }
            .scaleEffect(3)
            
        }.opacity(openedImmersiveSpace ? 0 : 1)
    }
    
}

#Preview(windowStyle: .volumetric) {
    ContentView()
}
