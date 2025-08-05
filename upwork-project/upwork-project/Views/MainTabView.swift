//
//  MainTabView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI
import Foundation
import Combine

struct MainTabView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var locationManager = LocationManager()
    @StateObject private var geocodingService = GeocodingService()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(0)
            
            LocationSuggestionView(
                userLocation: locationManager.userLocation,
                currentLocationName: geocodingService.currentLocationName
            )
                .environmentObject(dataManager)
                .environmentObject(locationManager)
                .tabItem {
                    Image(systemName: "location.magnifyingglass")
                    Text("Discover")
                }
                .tag(1)
            
            SubmitLocationView()
                .tabItem {
                    Image(systemName: "plus")
                    Text("Submit")
                }
                .tag(2)
        }
        .environmentObject(dataManager)
        .environmentObject(locationManager)
        .preferredColorScheme(.dark)
        .accentColor(.white)
        .onAppear {
            setupTabBarAppearance()
        }
        // Refresh notifications periodically
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            if dataManager.isAuthenticated {
                dataManager.loadNotifications()
            }
        }
    }
    
    private func setupTabBarAppearance() {
        // Set the tab bar appearance to match Citizen's black theme
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        
        // Unselected item appearance
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.gray
        ]
        
        // Selected item appearance  
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// Extension to conditionally apply modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(DataManager())
}
