//
//  HandsTestApp.swift
//  HandsTest
//
//  Created by Ben Harraway on 15/12/2023.
//

import SwiftUI

@main
struct HandsTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.windowStyle(.volumetric)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
