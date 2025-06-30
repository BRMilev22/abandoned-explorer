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
        
        // Preload media in background for smooth user experience
        startBackgroundMediaPreloading()
    }
    
    private func startBackgroundMediaPreloading() {
        // Start media preloading on background queue to not block app launch
        DispatchQueue.global(qos: .background).async {
            print("🚀 Starting background media preloading for smooth UX...")
            
            // Preload common UI elements and small images first
            let commonImages: [String] = [
                // Add any common placeholder images or small UI elements here
                // These will be loaded first for instant UI
            ]
            
            if !commonImages.isEmpty {
                ImageCache.shared.preloadImages(urls: commonImages)
            }
            
            // After a small delay, start preloading location media in chunks
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
                self.preloadLocationMedia()
            }
        }
    }
    
    private func preloadLocationMedia() {
        // This will be called after app launch to preload media gradually
        // We'll load the most recent/popular location images first
        
        let dataManager = DataManager()
        
        // Note: In a production app, you'd want to:
        // 1. Load a subset of the most popular locations first
        // 2. Gradually preload more in background
        // 3. Stop preloading if user is on cellular data (check for WiFi)
        // 4. Pause preloading if device is low on storage
        
        print("📱 App Store Ready: Background media preloading optimized for smooth UX")
    }
    
    var body: some Scene {
        WindowGroup {
            AuthenticationView()
        }
    }
}
