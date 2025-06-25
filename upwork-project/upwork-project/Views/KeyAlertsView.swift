//
//  KeyAlertsView.swift
//  upwork-project
//
//  Created by Boris Milev on 24.06.25.
//

import SwiftUI
import CoreLocation

struct KeyAlertsView: View {
    let locations: [AbandonedLocation]
    let userLocation: CLLocationCoordinate2D?
    let currentLocationName: String
    @Environment(\.dismiss) private var dismiss
    
    // Filter locations to show nearby dangerous ones first
    private var nearbyAlerts: [AbandonedLocation] {
        guard let userLoc = userLocation else {
            return locations.filter { $0.danger == .dangerous }
                .sorted { $0.submissionDate > $1.submissionDate }
        }
        
        return locations
            .filter { $0.danger == .dangerous || $0.submissionDate > Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() }
            .map { location in
                let distance = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                    .distance(from: CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
                return (location, distance)
            }
            .sorted { $0.1 < $1.1 } // Sort by distance
            .map { $0.0 }
            .prefix(20) // Limit to 20 results
            .map { $0 }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Key Alerts")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("Reports near \(currentLocationName)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Live indicator
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(1.0)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                                    
                                    Text("LIVE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(12)
                            }
                            
                            // Stats row
                            HStack(spacing: 20) {                            AlertStatCard(
                                title: "High Risk",
                                count: locations.filter { $0.danger == .dangerous }.count,
                                color: .red,
                                icon: "exclamationmark.triangle.fill"
                            )
                            
                            AlertStatCard(
                                title: "Recent",
                                count: locations.filter {
                                    $0.submissionDate > Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                                }.count,
                                color: .orange,
                                icon: "clock.fill"
                            )
                            
                            AlertStatCard(
                                title: "This Week",
                                count: locations.filter {
                                    $0.submissionDate > Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                                }.count,
                                color: .yellow,
                                icon: "calendar"
                            )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                        
                        // Alerts list
                        if nearbyAlerts.isEmpty {
                            EmptyAlertsView()
                        } else {
                            ForEach(Array(nearbyAlerts.enumerated()), id: \.element.id) { index, location in
                                AlertCard(
                                    location: location,
                                    userLocation: userLocation,
                                    isFirst: index == 0,
                                    isLast: index == nearbyAlerts.count - 1
                                )
                            }
                        }
                        
                        // Bottom padding for safe area
                        Color.clear.frame(height: 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .overlay(
            // Custom navigation bar
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button("Filter") {
                        // Filter action
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
            }
        )
    }
}

// MARK: - Supporting Views

struct AlertStatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AlertCard: View {
    let location: AbandonedLocation
    let userLocation: CLLocationCoordinate2D?
    let isFirst: Bool
    let isLast: Bool
    
    private var distance: String {
        guard let userLoc = userLocation else { return "" }
        
        let userCLLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let locationCLLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: locationCLLocation)
        
        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters))m away"
        } else {
            let distanceInKm = distanceInMeters / 1000
            if distanceInKm < 10 {
                return String(format: "%.1fkm away", distanceInKm)
            } else {
                return "\(Int(distanceInKm))km away"
            }
        }
    }
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(location.submissionDate)
        
        if interval < 3600 { // Less than 1 hour
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 { // Less than 1 day
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    private var dangerColor: Color {
        switch location.danger {
        case .safe:
            return .green
        case .caution:
            return .orange
        case .dangerous:
            return .red
        }
    }
    
    private var categoryIcon: String {
        switch location.category {
        case .hospital:
            return "cross.fill"
        case .factory:
            return "building.2.fill"
        case .school:
            return "graduationcap.fill"
        case .house:
            return "house.fill"
        case .mall:
            return "storefront.fill"
        case .church:
            return "building.columns.fill"
        case .theater:
            return "theatermasks.fill"
        case .other:
            return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Category icon with danger level indicator
                ZStack {
                    Circle()
                        .fill(dangerColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(dangerColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(location.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if location.danger == .dangerous {
                            Text("HIGH RISK")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red)
                                .cornerRadius(6)
                        }
                    }
                    
                    Text(location.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack(spacing: 16) {
                        if !distance.isEmpty {
                            Label(distance, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Label(timeAgo, systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Interaction stats
                        HStack(spacing: 12) {
                            if location.likeCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                    Text("\(location.likeCount)")
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                            }
                            
                            // Note: Using a placeholder for comments count since it's not in the model
                            let commentsCount = 0 // Placeholder - would need to be added to API
                            if commentsCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "bubble.fill")
                                    Text("\(commentsCount)")
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black)
            
            // Separator (except for last item)
            if !isLast {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5)
                    .padding(.leading, 84) // Align with content
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle tap - navigate to location detail
        }
    }
}

struct EmptyAlertsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("All Clear!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("No high-risk alerts in your area right now.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
    }
}

#Preview {
    KeyAlertsView(
        locations: [],
        userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        currentLocationName: "San Francisco, CA"
    )
}
