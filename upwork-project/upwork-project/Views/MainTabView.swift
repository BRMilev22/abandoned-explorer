//
//  MainTabView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var locationManager = LocationManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "location.fill" : "location")
                    Text("Map")
                }
                .tag(0)
            
            FeedView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "person.2.fill" : "person.2")
                    Text("Alert Community")
                }
                .tag(1)
            
            // News tab with red badge (like in Citizen)
            NewsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "globe.americas.fill" : "globe.americas")
                    Text("News")
                }
                .badge(12) // Red notification badge like in Citizen
                .tag(2)
            
            SubmitLocationView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Submit")
                }
                .tag(3)
            
            // Admin tab - only visible to admin users
            if dataManager.isAdmin {
                AdminPanelView()
                    .tabItem {
                        Image(systemName: "shield.fill")
                        Text("Admin")
                    }
                    .tag(4)
            }
        }
        .environmentObject(dataManager)
        .environmentObject(locationManager)
        .preferredColorScheme(.dark)
        .accentColor(.white)
        .onAppear {
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
}

#Preview {
    MainTabView()
        .environmentObject(DataManager())
}
