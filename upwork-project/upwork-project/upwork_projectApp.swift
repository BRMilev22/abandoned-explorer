//
//  upwork_projectApp.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI

@main
struct upwork_projectApp: App {
    
    init() {
        // Configure Mapbox on app startup
        MapboxConfiguration.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            AuthenticationView()
        }
    }
}
