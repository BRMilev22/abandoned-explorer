//
//  SubmitLocationView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI
import PhotosUI
import CoreLocation
import MapboxMaps
import Combine

struct SubmitLocationView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    @State private var selectedCategory: AbandonedPlaceCategory = .hospital
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationDescription = ""
    @State private var storyText = ""
    @State private var title = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var useCurrentLocation = false
    @State private var preciseLocation = true
    
    private let totalSteps = 5
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if currentStep == 0 {
                IntroScreen()
            } else {
                VStack(spacing: 0) {
                    // Header with progress
                    SubmissionHeader(currentStep: currentStep, totalSteps: totalSteps, onClose: {
                        dismiss()
                    })
                    
                    // Progress bar
                    ProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
                    
                    // Content
                    TabView(selection: $currentStep) {
                        IntroScreen().tag(0)
                        CategorySelectionScreen().tag(1)
                        MediaUploadScreen().tag(2)
                        LocationSelectionScreen().tag(3)
                        StoryDetailsScreen().tag(4)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)
                }
            }
            
            // Success overlay
            if showSuccess {
                SuccessOverlay {
                    showSuccess = false
                    resetForm()
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: dataManager.submissionSuccess) { _, success in
            if success {
                showSuccess = true
                dataManager.submissionSuccess = false
            }
        }
    }
    
    // MARK: - Intro Screen
    @ViewBuilder
    private func IntroScreen() -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Video placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.1))
                .frame(height: 300)
                .overlay(
                    VStack(spacing: 16) {
                        // Play button
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .offset(x: 3) // Slight offset to center the play icon
                            )
                        
                        Text("Preview Video")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                )
                .padding(.horizontal, 40)
            
            Spacer().frame(height: 60)
            
            VStack(spacing: 16) {
                Text("Share your exploration story")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Your experience is valued. Sharing it helps expand the conversation and build the community. The more we share, the closer we are to preserving these places.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
            
            Spacer().frame(height: 80)
            
            // Start button
            Button(action: {
                withAnimation(.spring()) {
                    currentStep = 1
                }
            }) {
                Text("Start")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
                    .padding(.horizontal, 60)
            }
            
            Spacer().frame(height: 60)
        }
    }
    
    // MARK: - Category Selection Screen
    @ViewBuilder
    private func CategorySelectionScreen() -> some View {
        VStack(spacing: 20) {
            Text("Before submitting, consider whether what you saw behaved like the places below. These known types are often confused with unique abandoned locations.")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: {
                // Add "Read More" action if needed
            }) {
                Text("Read More")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
            }
            .padding(.bottom, 20)
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(AbandonedPlaceCategory.allCases, id: \.self) { category in
                        CategoryCard(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Continue button
            Button(action: {
                withAnimation(.spring()) {
                    currentStep = 2
                }
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Media Upload Screen
    @ViewBuilder
    private func MediaUploadScreen() -> some View {
        VStack(spacing: 30) {
            Text("Did you capture any media of the abandoned place?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text("\(photoImages.count) media files")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(photoImages.isEmpty ? .gray : .red)
            
            VStack(spacing: 20) {
                // Photo upload button
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    MediaUploadCard(
                        icon: "camera.fill",
                        title: "Add media from\nPhotos app",
                        subtitle: nil
                    )
                }
                
                // Video upload placeholder (can be implemented later)
                MediaUploadCard(
                    icon: "video.fill",
                    title: "Add video from\nCamera Roll",
                    subtitle: nil
                )
            }
            
            // Show selected photos
            if !photoImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<photoImages.count, id: \.self) { index in
                            VStack(spacing: 8) {
                                Image(uiImage: photoImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red, lineWidth: 2)
                                    )
                                
                                Text("Photo \(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Info section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.red)
                    Text("What makes good media?")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
                
                Text("• Clear, well-lit photos showing the building's condition\n• Multiple angles of the structure\n• Any unique architectural features\n• Signs or identifying markers")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.leading, 24)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Continue button
            Button(action: {
                withAnimation(.spring()) {
                    currentStep = 3
                }
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                photoImages = []
                for photo in newPhotos {
                    if let data = try? await photo.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photoImages.append(image)
                    }
                }
            }
        }
    }
    
    // MARK: - Location Selection Screen
    @ViewBuilder
    private func LocationSelectionScreen() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Where did the exploration occur?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Location input
                VStack(spacing: 0) {
                    TextField("Enter address or description", text: $locationDescription)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color(white: 0.1))
                        .cornerRadius(8, corners: [.topLeft, .topRight])
                    
                    if !locationDescription.isEmpty {
                        Button(action: {
                            locationDescription = ""
                        }) {
                            HStack {
                                Text("Clear")
                                    .foregroundColor(.red)
                                Spacer()
                                Image(systemName: "xmark")
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color(white: 0.05))
                            .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Current location button
                Button(action: {
                    useCurrentLocation.toggle()
                    if useCurrentLocation, let location = locationManager.userLocation {
                        selectedLocation = location
                        locationDescription = "Current Location"
                    }
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Current Location")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color(white: 0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                // Interactive Mapbox map
                LocationSelectionMapView(
                    selectedLocation: $selectedLocation,
                    preciseLocation: $preciseLocation,
                    userLocation: locationManager.userLocation
                )
                .frame(height: 300)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Selected location info
                if let selectedLocation = selectedLocation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Location:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Lat: \(String(format: "%.6f", selectedLocation.latitude))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        Text("Lng: \(String(format: "%.6f", selectedLocation.longitude))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
                
                // Precise location toggle
                HStack {
                    Text("Precise location on")
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: $preciseLocation)
                        .tint(.red)
                }
                .padding(.horizontal, 20)
                
                // Continue button
                Button(action: {
                    withAnimation(.spring()) {
                        currentStep = 4
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Story Details Screen
    @ViewBuilder
    private func StoryDetailsScreen() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("What's your exploration story?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Helpful information includes:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Set the scene. Where were you and what were you doing?")
                        BulletPoint("How did you feel during and after the exploration?")
                        BulletPoint("What were the weather and visibility conditions?")
                        BulletPoint("Did other explorers see it? What were their reactions?")
                        BulletPoint("What did the building look like?")
                        BulletPoint("How accessible was the location?")
                        BulletPoint("What drew your attention or made you think it was worth exploring?")
                    }
                }
                .padding(.horizontal, 20)
                
                            // Title input
            VStack(spacing: 8) {
                TextField("Enter a title for this location", text: $title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(16)
                    .background(Color(white: 0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                HStack {
                    Text("Title (required)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(title.count)")
                        .font(.system(size: 14))
                        .foregroundColor(title.count >= 3 ? .green : .gray)
                }
            }
            .padding(.horizontal, 20)
            
            // Story/Description input
            VStack(spacing: 8) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $storyText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .background(Color.clear)
                        .padding(16)
                        .onSubmit {
                            hideKeyboard()
                        }
                    
                    if storyText.isEmpty {
                        Text("Please enter at least 150 characters")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, 24)
                            .padding(.leading, 20)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 200)
                .background(Color(white: 0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                HStack {
                    Text("Description - Min 150 characters")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(storyText.count)")
                        .font(.system(size: 14))
                        .foregroundColor(storyText.count >= 150 ? .green : .gray)
                }
            }
            .padding(.horizontal, 20)
                
                // Audio recording option
                Button(action: {
                    // Implement audio recording
                }) {
                    Text("I prefer to record audio")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
                
                            // Submit button
            Button(action: {
                hideKeyboard()
                submitExploration()
            }) {
                if isSubmitting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                        Text("Submitting...")
                    }
                } else {
                    Text("Submit Exploration")
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background((storyText.count >= 150 && title.count >= 3) ? Color.white : Color.gray)
            .cornerRadius(25)
            .padding(.horizontal, 20)
            .disabled(storyText.count < 150 || title.count < 3 || isSubmitting)
            .padding(.bottom, 40)
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
        // MARK: - Helper Functions
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func resetForm() {
        currentStep = 0
        selectedCategory = .hospital
        selectedPhotos = []
        photoImages = []
        selectedLocation = nil
        locationDescription = ""
        storyText = ""
        title = ""
        useCurrentLocation = false
        preciseLocation = true
    }
    
    private func submitExploration() {
        isSubmitting = true
        
        let latitude = selectedLocation?.latitude ?? locationManager.userLocation?.latitude ?? 0.0
        let longitude = selectedLocation?.longitude ?? locationManager.userLocation?.longitude ?? 0.0
        
        // Use the actual title field, fallback to category if empty
        let finalTitle = title.isEmpty ? selectedCategory.rawValue : title
        
        dataManager.submitLocation(
            title: finalTitle,
            description: storyText,
            latitude: latitude,
            longitude: longitude,
            address: locationDescription.isEmpty ? "Lat: \(latitude), Lng: \(longitude)" : locationDescription,
            category: LocationCategory(rawValue: selectedCategory.rawValue) ?? .other,
            dangerLevel: .caution, // Default to caution for abandoned places
            tags: [selectedCategory.rawValue.lowercased()],
            images: photoImages
        )
        
        isSubmitting = false
    }
}

// MARK: - Supporting Views

struct SubmissionHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Text("Submit Exploration")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Invisible button for balance
            Button(action: {}) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.clear)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Rectangle()
                    .fill(step < currentStep ? Color.red : Color.gray.opacity(0.3))
                    .frame(height: 3)
                    .animation(.easeInOut, value: currentStep)
            }
        }
        .padding(.horizontal, 20)
    }
}



struct CategoryCard: View {
    let category: AbandonedPlaceCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Category image/icon
                Rectangle()
                    .fill(Color(white: 0.1))
                    .frame(height: 120)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: category.icon)
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .background(isSelected ? Color.red.opacity(0.2) : Color(white: 0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct MediaUploadCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.gray)
                .frame(width: 60, height: 60)
                .background(Color(white: 0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(white: 0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

struct LocationSelectionMapView: UIViewRepresentable {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var preciseLocation: Bool
    let userLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> MapboxMaps.MapView {
        let mapView = MapboxMaps.MapView(frame: .zero)
        mapView.backgroundColor = UIColor.black
        
        // Load dark style for consistency
        mapView.mapboxMap.loadStyle(.dark)
        
        // Set initial camera position
        let initialLocation = userLocation ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let cameraOptions = CameraOptions(
            center: initialLocation,
            zoom: 12.0
        )
        mapView.mapboxMap.setCamera(to: cameraOptions)
        
        // Setup tap gesture for location selection
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        context.coordinator.mapView = mapView
        context.coordinator.setupAnnotationManager()
        
        return mapView
    }
    
    func updateUIView(_ uiView: MapboxMaps.MapView, context: Context) {
        // Check if the selected location actually changed
        let hasLocationChanged: Bool
        if let lastLocation = context.coordinator.lastSelectedLocation,
           let currentLocation = selectedLocation {
            // Compare coordinates with small tolerance for floating point precision
            let latDiff = abs(lastLocation.latitude - currentLocation.latitude)
            let lngDiff = abs(lastLocation.longitude - currentLocation.longitude)
            hasLocationChanged = latDiff > 0.000001 || lngDiff > 0.000001
        } else {
            // One is nil and the other isn't, or both are nil
            hasLocationChanged = context.coordinator.lastSelectedLocation != nil || selectedLocation != nil
        }
        
        if hasLocationChanged {
            context.coordinator.lastSelectedLocation = selectedLocation
            context.coordinator.updateSelectedLocationMarker()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: LocationSelectionMapView
        var mapView: MapboxMaps.MapView?
        private var annotationManager: PointAnnotationManager?
        var lastSelectedLocation: CLLocationCoordinate2D?
        var hasRegisteredImages = false
        
        init(_ parent: LocationSelectionMapView) {
            self.parent = parent
        }
        
        func setupAnnotationManager() {
            guard let mapView = mapView else { return }
            annotationManager = mapView.annotations.makePointAnnotationManager()
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.mapboxMap.coordinate(for: point)
            
            print("📍 Location selected: \(coordinate)")
            
            DispatchQueue.main.async {
                self.parent.selectedLocation = coordinate
                // Update markers immediately
                self.updateSelectedLocationMarker()
            }
        }
        
        func updateSelectedLocationMarker() {
            guard let mapView = mapView, let annotationManager = annotationManager else { return }
            
            // Register marker images first (only once)
            if !hasRegisteredImages {
                let userMarkerImage = createUserLocationMarker()
                try? mapView.mapboxMap.addImage(userMarkerImage, id: "user-location-marker")
                
                let selectedMarkerImage = createSelectedLocationMarker()
                try? mapView.mapboxMap.addImage(selectedMarkerImage, id: "selected-location-marker")
                
                hasRegisteredImages = true
                print("🎨 Registered marker images")
            }
            
            // Clear existing annotations
            annotationManager.annotations = []
            
            var newAnnotations: [PointAnnotation] = []
            
            // Add user location marker if available
            if let userLocation = parent.userLocation {
                var userAnnotation = PointAnnotation(id: "user-location", coordinate: userLocation)
                userAnnotation.iconImage = "user-location-marker"
                userAnnotation.iconSize = 0.8
                userAnnotation.iconAnchor = .center
                newAnnotations.append(userAnnotation)
                print("👤 Added user location marker at \(userLocation)")
            }
            
            // Add selected location marker if available
            if let selectedLocation = parent.selectedLocation {
                var selectedAnnotation = PointAnnotation(id: "selected-location", coordinate: selectedLocation)
                selectedAnnotation.iconImage = "selected-location-marker"
                selectedAnnotation.iconSize = 1.0
                selectedAnnotation.iconAnchor = .center
                newAnnotations.append(selectedAnnotation)
                print("📍 Added selected location marker at \(selectedLocation)")
            }
            
            // Set all annotations at once
            annotationManager.annotations = newAnnotations
            print("📊 Total annotations: \(newAnnotations.count)")
        }
        
        private func createUserLocationMarker() -> UIImage {
            let size = CGSize(width: 20, height: 20)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let cgContext = context.cgContext
                let rect = CGRect(origin: .zero, size: size)
                
                // Blue circle for user location
                cgContext.setFillColor(UIColor.systemBlue.cgColor)
                cgContext.fillEllipse(in: rect)
                
                // White border
                cgContext.setStrokeColor(UIColor.white.cgColor)
                cgContext.setLineWidth(2)
                cgContext.strokeEllipse(in: rect)
            }
        }
        
        private func createSelectedLocationMarker() -> UIImage {
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let cgContext = context.cgContext
                let rect = CGRect(origin: .zero, size: size)
                
                // Red circle for selected location
                cgContext.setFillColor(UIColor.systemRed.cgColor)
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

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.gray)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
    }
}

struct SuccessOverlay: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Exploration Submitted!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Thank you for sharing your exploration. It will be reviewed and added to the map.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onDismiss) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(25)
                    .padding(.horizontal, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
        .onAppear {
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onDismiss()
            }
        }
    }
}

// MARK: - Enums

enum AbandonedPlaceCategory: String, CaseIterable {
    case hospital = "Hospital"
    case school = "School"
    case factory = "Factory"
    case house = "House"
    case church = "Church"
    case mall = "Mall"
    case theater = "Theater"
    case other = "Other"
    
    var displayName: String {
        switch self {
        case .hospital: return "HOSPITALS"
        case .school: return "SCHOOLS"
        case .factory: return "FACTORIES"
        case .house: return "HOUSES"
        case .church: return "CHURCHES"
        case .mall: return "MALLS"
        case .theater: return "THEATERS"
        case .other: return "OTHER"
        }
    }
    
    var icon: String {
        switch self {
        case .hospital: return "cross.fill"
        case .school: return "book.fill"
        case .factory: return "building.2.fill"
        case .house: return "house.fill"
        case .church: return "building.columns.fill"
        case .mall: return "bag.fill"
        case .theater: return "theatermasks.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    SubmitLocationView()
        .environmentObject(DataManager())
        .environmentObject(LocationManager())
}
