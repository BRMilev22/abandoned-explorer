//
//  AdminPanelView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI
import MapboxMaps
import CoreLocation
import AVKit

// MARK: - Helper Extensions
extension String {
    var isVideoURL: Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "webm"]
        let pathExtension = URL(string: self)?.pathExtension.lowercased() ?? ""
        let hasVideoExtension = videoExtensions.contains(pathExtension)
        let containsVideoKeyword = self.lowercased().contains("video_")
        
        return hasVideoExtension || containsVideoKeyword
    }
    
    var isImageURL: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff"]
        let pathExtension = URL(string: self)?.pathExtension.lowercased() ?? ""
        let hasImageExtension = imageExtensions.contains(pathExtension)
        let containsImageKeyword = self.lowercased().contains("original_") || self.lowercased().contains("thumb_")
        
        return hasImageExtension || containsImageKeyword
    }
}

// MARK: - Safe Media Display Helper
struct SafeMediaThumbnail: View {
    let url: String
    let size: CGFloat
    @State private var showingVideoPlayer = false
    
    var body: some View {
        if url.isEmpty {
            // Empty URL
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                )
                .frame(width: size, height: size)
        } else if url.isVideoURL {
            // Video thumbnail placeholder - make it tappable
            Button(action: {
                showingVideoPlayer = true
            }) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: size * 0.25))
                                .foregroundColor(.white)
                            Text("VIDEO")
                                .font(.system(size: max(8, size * 0.08), weight: .semibold))
                                .foregroundColor(.white)
                            Text("Tap to play")
                                .font(.system(size: max(6, size * 0.06)))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
                    .frame(width: size, height: size)
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showingVideoPlayer) {
                AdminVideoPlayerView(videoURL: url)
            }
        } else if url.isImageURL {
            // Safe image loading
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }
            .frame(width: size, height: size)
        } else {
            // Unknown format - show URL info for debugging
            Rectangle()
                .fill(Color.orange.opacity(0.3))
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: size * 0.2))
                            .foregroundColor(.orange)
                        Text("UNKNOWN")
                            .font(.system(size: max(8, size * 0.06), weight: .semibold))
                            .foregroundColor(.orange)
                        if size > 100 {
                            Text(URL(string: url)?.pathExtension.uppercased() ?? "?")
                                .font(.system(size: max(6, size * 0.05)))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                )
                .frame(width: size, height: size)
        }
    }
}

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
        SwiftUI.Group {
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
            AdminLocationDetailView(location: location)
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
                // Safe media display - get first available media (image or video)
                let firstMediaURL = {
                    // First try to get an image
                    if let firstImage = location.displayImages.first(where: { $0.isImageURL }) {
                        return firstImage
                    }
                    // If no images, try to get a video
                    if let firstVideo = location.displayVideos.first {
                        return firstVideo
                    }
                    // Fallback to first item in displayImages (legacy compatibility)
                    return location.displayImages.first ?? ""
                }()
                
                SafeMediaThumbnail(url: firstMediaURL, size: 80)
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

// MARK: - Admin Video Player View
struct AdminVideoPlayerView: View {
    let videoURL: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if let url = URL(string: videoURL) {
                    AdminVideoController(url: url)
                        .navigationTitle("Review Video")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    dismiss()
                                }
                            }
                        }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Invalid Video URL")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Unable to load video for review")
                            .foregroundColor(.secondary)
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Admin Video Controller
struct AdminVideoController: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        
        // Auto-play for admin review
        player.play()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}

struct AdminLocationDetailView: View {
    let location: AbandonedLocation
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with basic info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(location.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Label(location.category.rawValue, systemImage: "tag.fill")
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Label(location.danger.rawValue, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(dangerLevelColor(location.danger))
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Submission Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Submission Details")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Submitted by", value: location.submittedByUsername ?? "User \(location.submittedBy ?? 0)")
                            InfoRow(label: "Submission date", value: DateFormatter.adminStyle.string(from: location.submissionDate))
                            InfoRow(label: "Location ID", value: "\(location.id)")
                            InfoRow(label: "Address", value: location.address)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Location Coordinates
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Geographic Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Latitude", value: String(format: "%.6f", location.latitude))
                            InfoRow(label: "Longitude", value: String(format: "%.6f", location.longitude))
                            InfoRow(label: "Coordinates", value: "\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude))")
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Map Visualization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location on Map")
                            .font(.headline)
                        
                        AdminMapView(location: location)
                            .frame(height: 250)
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(location.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Images and Videos
                    let imageURLs = location.displayImages.filter { $0.isImageURL }
                    let videoURLs = location.displayVideos
                    
                    if !imageURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Images (\(imageURLs.count))")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<imageURLs.count, id: \.self) { index in
                                        SafeMediaThumbnail(url: imageURLs[index], size: 150)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Videos section
                    if !videoURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Videos (\(videoURLs.count))")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<videoURLs.count, id: \.self) { index in
                                        SafeMediaThumbnail(url: videoURLs[index], size: 150)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Tags
                    if !location.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(location.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Admin Actions
                    HStack(spacing: 16) {
                        Button("Reject") {
                            isProcessing = true
                            dataManager.rejectLocation(location.id)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isProcessing)
                        
                        Button("Approve") {
                            isProcessing = true
                            dataManager.approveLocation(location.id)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isProcessing)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle("Location Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func dangerLevelColor(_ danger: DangerLevel) -> Color {
        switch danger {
        case .safe: return .green
        case .caution: return .yellow
        case .dangerous: return .red
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct AdminMapView: UIViewRepresentable {
    let location: AbandonedLocation
    
    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let mapView = MapboxMaps.MapView(frame: .zero)
        mapView.backgroundColor = UIColor.black
        
        // Load dark style
        mapView.mapboxMap.loadStyle(.dark)
        
        // Set camera to location
        let cameraOptions = CameraOptions(
            center: location.coordinate,
            zoom: 14.0
        )
        mapView.mapboxMap.setCamera(to: cameraOptions)
        
        context.coordinator.mapView = mapView
        context.coordinator.setupAnnotation()
        
        return mapView
    }
    
    func updateUIView(_ uiView: MapboxMaps.MapView, context: Context) {
        // No updates needed for static display
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: AdminMapView
        var mapView: MapboxMaps.MapView?
        
        init(_ parent: AdminMapView) {
            self.parent = parent
        }
        
        func setupAnnotation() {
            guard let mapView = mapView else { return }
            
            let annotationManager = mapView.annotations.makePointAnnotationManager()
            
            // Create marker image
            let markerImage = createLocationMarker()
            try? mapView.mapboxMap.addImage(markerImage, id: "location-marker")
            
            // Add annotation
            var annotation = PointAnnotation(coordinate: parent.location.coordinate)
            annotation.iconImage = "location-marker"
            annotation.iconSize = 1.0
            annotation.iconAnchor = .center
            
            annotationManager.annotations = [annotation]
        }
        
        private func createLocationMarker() -> UIImage {
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let cgContext = context.cgContext
                let rect = CGRect(origin: .zero, size: size)
                
                // Orange circle for location
                cgContext.setFillColor(UIColor.systemOrange.cgColor)
                cgContext.fillEllipse(in: rect)
                
                // White border
                cgContext.setStrokeColor(UIColor.white.cgColor)
                cgContext.setLineWidth(3)
                cgContext.strokeEllipse(in: rect)
                
                // Inner white dot
                let innerRect = CGRect(x: 16, y: 16, width: 8, height: 8)
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fillEllipse(in: innerRect)
            }
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

extension DateFormatter {
    static let adminStyle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    AdminPanelView()
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
