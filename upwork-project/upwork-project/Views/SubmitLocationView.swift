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
import AVKit
import AVFoundation

struct SubmitLocationView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    @State private var selectedCategory: AbandonedPlaceCategory = .hospital
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var videoURLs: [URL] = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationDescription = ""
    @State private var selectedTags: Set<ExplorationTag> = []
    @State private var selectedDangerLevel: DangerLevel = .caution
    @State private var explorationDate = Date()
    @State private var explorationTime: ExplorationTime = .day
    @State private var title = ""
    @State private var storyText = ""
    @State private var companionCount = 0
    @State private var companionNames = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var useCurrentLocation = false
    @State private var preciseLocation = true
    
    private let totalSteps = 8
    
    // App color scheme
    private let accentColor = Color(hex: "#7289da") // Light purple/blue
    
    // Step completion validation
    private var isStep1Complete: Bool {
        // Media upload step - at least one photo or video
        return !photoImages.isEmpty || !videoURLs.isEmpty
    }
    
    private var isStep2Complete: Bool {
        // Location selection step - location must be selected
        return selectedLocation != nil || useCurrentLocation
    }
    
    private var isStep3Complete: Bool {
        // Tag selection step - at least one tag selected
        return !selectedTags.isEmpty
    }
    
    private var isStep4Complete: Bool {
        // Danger level step - always complete since default is set
        return true
    }
    
    private var isStep5Complete: Bool {
        // Date/time step - always complete since defaults are set
        return true
    }
    
    private var isStep6Complete: Bool {
        // Title/description step - title must have at least 3 characters
        return title.count >= 3
    }
    
    private var isStep7Complete: Bool {
        // Companion step - always complete since default is set
        return true
    }
    
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
                         MediaUploadScreen().tag(1)
                         LocationSelectionScreen().tag(2)
                         TagSelectionScreen().tag(3)
                         DangerLevelScreen().tag(4)
                         DateTimeScreen().tag(5)
                         TitleDescriptionScreen().tag(6)
                         CompanionScreen().tag(7)
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
        ZStack {
            // Subtle background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(hex: "#1a1a2e").opacity(0.8),
                    Color(hex: "#16213e").opacity(0.6),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
            
            // Video player with glow effect
            ZStack {
                // Background glow rectangles for ambient light effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#7289da").opacity(0.4),
                                Color(hex: "#4169e1").opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 100,
                            endRadius: 200
                        )
                    )
                    .frame(height: 300)
                    .scaleEffect(1.2)
                    .blur(radius: 15)
                
                // Main video with border
                if let videoURL = Bundle.main.url(forResource: "submission_video", withExtension: "mp4") {
                    FullScreenVideoPlayer(url: videoURL)
                        .frame(height: 300)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: Color(hex: "#7289da").opacity(0.6), radius: 25, x: 0, y: 0)
                } else {
                    // Debug: Show if video file is not found
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.1))
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                    .foregroundColor(.yellow)
                                
                                Text("Video not found")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("submission_video.mp4")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: Color(hex: "#7289da").opacity(0.6), radius: 25, x: 0, y: 0)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer().frame(height: 60)
            
            VStack(spacing: 16) {
                Text("Share your sighting story")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Your experience is valued. Sharing it helps expand the conversation and build the community. The more we share, the closer we are to solving the mystery.")
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
                     currentStep = 1
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
        ScrollView {
            VStack(spacing: 20) {
                Text("Did you capture any media of the abandoned place?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                Text("\(photoImages.count + videoURLs.count) media files")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor((photoImages.isEmpty && videoURLs.isEmpty) ? .gray : .red)
                
                if !isStep1Complete {
                    Text("Please add at least one photo or video to continue")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 16) {
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
                    
                    // Video upload from Photos
                    PhotosPicker(
                        selection: $selectedVideos,
                        maxSelectionCount: 3,
                        matching: .videos
                    ) {
                        MediaUploadCard(
                            icon: "video.fill",
                            title: "Add video from\nCamera Roll",
                            subtitle: nil
                        )
                    }
                }
                
                // Show selected photos
                if !photoImages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photos (\(photoImages.count))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
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
                }
                
                // Show selected videos
                if !videoURLs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Videos (\(videoURLs.count))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<videoURLs.count, id: \.self) { index in
                                    VStack(spacing: 8) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(white: 0.2))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                VStack {
                                                    Image(systemName: "play.circle.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.white)
                                                    Text("MP4")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.blue, lineWidth: 2)
                                            )
                                        
                                        Text("Video \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
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
                    
                    Text("• Clear, well-lit photos/videos showing the building's condition\n• Multiple angles of the structure\n• Any unique architectural features\n• Signs or identifying markers\n• Short videos showing movement or atmosphere")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.leading, 24)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Continue button
                Button(action: {
                    withAnimation(.spring()) {
                        currentStep = 2
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isStep1Complete ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isStep1Complete ? Color.white : Color.gray.opacity(0.3))
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                }
                .disabled(!isStep1Complete)
                .padding(.bottom, 40)
            }
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
        .onChange(of: selectedVideos) { _, newVideos in
            Task {
                videoURLs = []
                for video in newVideos {
                    do {
                        // Load video data and create temporary file URL
                        if let data = try await video.loadTransferable(type: Data.self) {
                            // Create temporary file URL
                            let tempDirectory = FileManager.default.temporaryDirectory
                            let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                            
                            try data.write(to: tempURL)
                            videoURLs.append(tempURL)
                            print("✅ Video loaded successfully: \(tempURL.lastPathComponent)")
                        }
                    } catch {
                        print("❌ Failed to load video: \(error)")
                    }
                }
                print("📹 Total videos loaded: \(videoURLs.count)")
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
                
                if !isStep2Complete {
                    Text("Please select a location on the map or use current location to continue")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
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
                        .tint(accentColor)
                }
                .padding(.horizontal, 20)
                
                // Continue button
                Button(action: {
                    withAnimation(.spring()) {
                        currentStep = 3
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isStep2Complete ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isStep2Complete ? Color.white : Color.gray.opacity(0.3))
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                }
                .disabled(!isStep2Complete)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Tag Selection Screen
    @ViewBuilder
    private func TagSelectionScreen() -> some View {
        VStack(spacing: 20) {
            Text("Add tags to describe this place")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text("Select all that apply")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            if !isStep3Complete {
                Text("Please select at least one tag to continue")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(ExplorationTag.allCases, id: \.self) { tag in
                        TagCard(
                            tag: tag,
                            isSelected: selectedTags.contains(tag)
                        ) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Continue button
            Button(action: {
                withAnimation(.spring()) {
                    currentStep = 4
                }
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isStep3Complete ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isStep3Complete ? Color.white : Color.gray.opacity(0.3))
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
            }
            .disabled(!isStep3Complete)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Danger Level Screen
    @ViewBuilder
    private func DangerLevelScreen() -> some View {
        VStack(spacing: 30) {
            Text("How safe is this location?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text("Select the safety level based on your exploration experience")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                ForEach(DangerLevel.allCases, id: \.self) { level in
                    DangerLevelCard(
                        level: level,
                        isSelected: selectedDangerLevel == level
                    ) {
                        selectedDangerLevel = level
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Continue button
            Button(action: {
                withAnimation(.spring()) {
                    currentStep = 5
                }
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isStep4Complete ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isStep4Complete ? Color.white : Color.gray.opacity(0.3))
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
            }
            .disabled(!isStep4Complete)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Date/Time Screen
    @ViewBuilder
    private func DateTimeScreen() -> some View {
        VStack(spacing: 30) {
            Text("When did you explore this place?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            VStack(spacing: 20) {
                // Date picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    DatePicker("", selection: $explorationDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .accentColor(accentColor)
                        .colorScheme(.dark)
                }
                .padding()
                .background(Color(white: 0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Time of day
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time of day")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        ForEach(ExplorationTime.allCases, id: \.self) { time in
                            TimeCard(
                                time: time,
                                isSelected: explorationTime == time
                            ) {
                                explorationTime = time
                            }
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Continue button
            Button(action: {
                withAnimation(.spring()) {
                    currentStep = 6
                }
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isStep5Complete ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isStep5Complete ? Color.white : Color.gray.opacity(0.3))
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
            }
            .disabled(!isStep5Complete)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Title/Description Screen
    @ViewBuilder
    private func TitleDescriptionScreen() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Tell us about your exploration")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                if !isStep6Complete {
                    Text("Please enter a title with at least 3 characters to continue")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
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
                
                // Description input
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
                            Text("Describe your exploration experience...")
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
                        Text("Description (optional)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(storyText.count)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                
                // Continue button
                Button(action: {
                    hideKeyboard()
                    withAnimation(.spring()) {
                        currentStep = 7
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isStep6Complete ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isStep6Complete ? Color.white : Color.gray.opacity(0.3))
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                }
                .disabled(!isStep6Complete)
                .padding(.bottom, 40)
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Companion Screen
    @ViewBuilder
    private func CompanionScreen() -> some View {
        VStack(spacing: 30) {
            Text("Did you go with any other users?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            VStack(spacing: 20) {
                // Number of companions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Number of companions")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        ForEach(0...5, id: \.self) { count in
                            CompanionCountButton(
                                count: count,
                                isSelected: companionCount == count
                            ) {
                                companionCount = count
                                if count == 0 {
                                    companionNames = ""
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Companion names (if any)
                if companionCount > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Companion names (optional)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        TextField("Enter names separated by commas", text: $companionNames)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color(white: 0.05))
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(white: 0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            Spacer()
            
            // Auto-submit button
            Button(action: {
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
            .background(Color.white)
            .cornerRadius(25)
            .padding(.horizontal, 20)
            .disabled(isSubmitting)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Story Details Screen (Legacy - Remove)
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
        selectedVideos = []
        videoURLs = []
        selectedLocation = nil
        locationDescription = ""
        selectedTags = []
        selectedDangerLevel = .caution
        explorationDate = Date()
        explorationTime = .day
        title = ""
        storyText = ""
        companionCount = 0
        companionNames = ""
        useCurrentLocation = false
        preciseLocation = true
    }
    
    private func submitExploration() {
        isSubmitting = true
        
        let latitude = selectedLocation?.latitude ?? locationManager.userLocation?.latitude ?? 0.0
        let longitude = selectedLocation?.longitude ?? locationManager.userLocation?.longitude ?? 0.0
        
        // Use the actual title field, fallback to category if empty
        let finalTitle = title.isEmpty ? selectedCategory.rawValue : title
        
        // Combine selected tags with category
        var allTags = selectedTags.map { $0.name.lowercased() }
        allTags.append(selectedCategory.rawValue.lowercased())
        
        // Add exploration time and companion info to description
        var fullDescription = storyText
        if !storyText.isEmpty {
            fullDescription += "\n\n"
        }
        fullDescription += "Explored on: \(DateFormatter.localizedString(from: explorationDate, dateStyle: .medium, timeStyle: .none))"
        fullDescription += "\nTime of day: \(explorationTime.name)"
        if companionCount > 0 {
            fullDescription += "\nCompanions: \(companionCount)"
            if !companionNames.isEmpty {
                fullDescription += " (\(companionNames))"
            }
        } else {
            fullDescription += "\nExplored solo"
        }
        
        dataManager.submitLocation(
            title: finalTitle,
            description: fullDescription,
            latitude: latitude,
            longitude: longitude,
            address: locationDescription.isEmpty ? "Lat: \(latitude), Lng: \(longitude)" : locationDescription,
            category: LocationCategory(rawValue: selectedCategory.rawValue) ?? .other,
            dangerLevel: selectedDangerLevel,
            tags: allTags,
            images: photoImages,
            videos: videoURLs
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
                    .fill(step < currentStep ? Color(hex: "#7289da") : Color.gray.opacity(0.3))
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

enum ExplorationTag: String, CaseIterable, Hashable {
    case abandoned = "🏚️ Abandoned"
    case creepy = "😨 Creepy"
    case nature = "🏞️ Nature"
    case suburban = "🏘️ Suburban"
    case rural = "🐓 Rural"
    case squatters = "🧎‍♂️‍➡️ Squatters"
    case graffiti = "🎨 Graffiti"
    case decay = "🏗️ Decay"
    case overgrown = "🌿 Overgrown"
    case industrial = "🏭 Industrial"
    case historical = "📜 Historical"
    case dangerous = "⚠️ Dangerous"
    
    var emoji: String {
        return String(rawValue.prefix(2))
    }
    
    var name: String {
        return String(rawValue.dropFirst(2))
    }
}

enum ExplorationTime: String, CaseIterable {
    case dawn = "🌅 Dawn"
    case day = "☀️ Day"
    case dusk = "🌆 Dusk"
    case night = "🌙 Night"
    
    var emoji: String {
        return String(rawValue.prefix(2))
    }
    
    var name: String {
        return String(rawValue.dropFirst(2))
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

struct TagCard: View {
    let tag: ExplorationTag
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(tag.emoji)
                    .font(.system(size: 24))
                    .fixedSize()
                
                Text(tag.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color(hex: "#7289da").opacity(0.3) : Color(white: 0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "#7289da") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TimeCard: View {
    let time: ExplorationTime
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(time.emoji)
                    .font(.system(size: 24))
                
                Text(time.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: "#7289da").opacity(0.3) : Color(white: 0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(hex: "#7289da") : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct CompanionCountButton: View {
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(count == 0 ? "Solo" : "\(count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.white : Color(white: 0.1))
                .cornerRadius(22)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct DangerLevelCard: View {
    let level: DangerLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    private var levelColor: Color {
        switch level {
        case .safe: return .green
        case .caution: return .yellow
        case .dangerous: return .red
        }
    }
    
    private var levelIcon: String {
        switch level {
        case .safe: return "shield.checkered"
        case .caution: return "exclamationmark.triangle"
        case .dangerous: return "exclamationmark.triangle.fill"
        }
    }
    
    private var levelDescription: String {
        switch level {
        case .safe: return "Generally safe to explore with basic precautions"
        case .caution: return "Requires caution and proper safety equipment"
        case .dangerous: return "High risk - experienced explorers only"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(levelColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: levelIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(levelColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(levelDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection indicator
                Circle()
                    .fill(isSelected ? levelColor : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? levelColor : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isSelected ? .black : .clear)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isSelected ? levelColor.opacity(0.1) : Color(white: 0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? levelColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
            }
}

// MARK: - Full Screen Video Player (No Black Bars)

struct FullScreenVideoPlayer: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        containerView.clipsToBounds = true
        
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        
        // This removes black bars by filling the entire frame
        playerLayer.videoGravity = .resizeAspectFill
        
        // Adjust the frame to show more of the person running on the left side
        // Make the player layer wider and offset it to the left to show more of the left portion
        let bounds = containerView.bounds
        let adjustedWidth = bounds.width * 1.4 // Make it 40% wider
        let adjustedHeight = bounds.height * 1.2 // Make it 20% taller  
        let xOffset = -bounds.width * 0.05 // Shift left by 5% to fill the blue gap completely
        let yOffset = -bounds.height * 0.1 // Slight up shift to show ground level
        
        playerLayer.frame = CGRect(
            x: xOffset,
            y: yOffset,
            width: adjustedWidth,
            height: adjustedHeight
        )
        
        containerView.layer.addSublayer(playerLayer)
        
        // Setup autoplay
        player.isMuted = true
        player.play()
        
        // Setup looping
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.restartVideo),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        context.coordinator.containerView = containerView
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update layer frame when view size changes
        DispatchQueue.main.async {
            let bounds = uiView.bounds
            let adjustedWidth = bounds.width * 1.4
            let adjustedHeight = bounds.height * 1.2
            let xOffset = -bounds.width * 0.05
            let yOffset = -bounds.height * 0.1
            
            context.coordinator.playerLayer?.frame = CGRect(
                x: xOffset,
                y: yOffset,
                width: adjustedWidth,
                height: adjustedHeight
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var containerView: UIView?
        
        @objc func restartVideo() {
            player?.seek(to: CMTime.zero)
            player?.play()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            player?.pause()
        }
    }
}

#Preview {
    SubmitLocationView()
        .environmentObject(DataManager())
        .environmentObject(LocationManager())
}
