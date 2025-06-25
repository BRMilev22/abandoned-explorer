//
//  AdminPanelView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedSegment = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Admin Actions", selection: $selectedSegment) {
                    Text("Pending Locations").tag(0)
                    Text("Statistics").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedSegment == 0 {
                    PendingLocationsView()
                } else {
                    AdminStatisticsView()
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Always load pending locations when admin panel appears
                if dataManager.isAdmin {
                    dataManager.loadPendingLocations()
                }
            }
            .alert("Admin Panel", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: dataManager.errorMessage) { _, errorMessage in
                if let error = errorMessage, !error.isEmpty {
                    alertMessage = error
                    showingAlert = true
                }
            }
        }
    }
}

struct PendingLocationsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingLocationDetail: AbandonedLocation?
    
    var body: some View {
        Group {
            if dataManager.isLoading {
                ProgressView("Loading pending locations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if dataManager.pendingLocations.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    Text("No Pending Locations")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("All submitted locations have been reviewed.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(dataManager.pendingLocations) { location in
                        PendingLocationRow(location: location, showingLocationDetail: $showingLocationDetail)
                    }
                }
                .refreshable {
                    dataManager.loadPendingLocations()
                }
            }
        }
        .sheet(item: $showingLocationDetail) { location in
            LocationDetailView(location: location, isAdminReview: true)
        }
    }
}

struct PendingLocationRow: View {
    let location: AbandonedLocation
    @Binding var showingLocationDetail: AbandonedLocation?
    @EnvironmentObject var dataManager: DataManager
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CachedAsyncImage(url: location.displayImages.first ?? "") { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(location.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack {
                        Text("Submitted by: \(location.submittedByUsername ?? "User \(location.submittedBy ?? 0)")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(location.submissionDate, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("View Details") {
                    // Ensure we have valid location data before showing detail
                    if !location.title.isEmpty {
                        showingLocationDetail = location
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.blue)
                
                Spacer()
                
                Button("Reject") {
                    isProcessing = true
                    dataManager.rejectLocation(location.id)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .disabled(isProcessing)
                
                Button("Approve") {
                    isProcessing = true
                    dataManager.approveLocation(location.id)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 8)
        .onChange(of: dataManager.pendingLocations.count) { _, _ in
            isProcessing = false
        }
    }
}

struct AdminStatisticsView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var totalLocations: Int {
        dataManager.locations.count
    }
    
    var approvedLocations: Int {
        dataManager.locations.filter { $0.isApproved }.count
    }
    
    var pendingCount: Int {
        dataManager.pendingLocations.count
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                AdminStatCard(
                    title: "Total Locations",
                    value: "\(totalLocations)",
                    icon: "location.fill",
                    color: .blue
                )
                
                AdminStatCard(
                    title: "Approved Locations",
                    value: "\(approvedLocations)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                AdminStatCard(
                    title: "Pending Review",
                    value: "\(pendingCount)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                AdminStatCard(
                    title: "Total Users",
                    value: "N/A",
                    icon: "person.2.fill",
                    color: .purple
                )
            }
            .padding()
        }
    }
}

struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title2)
                    
                    Spacer()
                    
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    AdminPanelView()
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
