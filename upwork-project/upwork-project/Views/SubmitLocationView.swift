//
//  SubmitLocationView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI
import PhotosUI

struct SubmitLocationView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var currentStep = 0
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: LocationCategory = .other
    @State private var selectedDangerLevel: DangerLevel = .safe
    @State private var tags = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var locationString = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var isGettingLocation = false
    
    private let steps = ["Basic Info", "Details", "Photos", "Location", "Review"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                ProgressBar(currentStep: currentStep, totalSteps: steps.count)
                    .padding()
                
                // Step Content
                TabView(selection: $currentStep) {
                    // Step 1: Basic Info
                    BasicInfoStep(
                        title: $title,
                        description: $description
                    )
                    .tag(0)
                    
                    // Step 2: Details
                    DetailsStep(
                        selectedCategory: $selectedCategory,
                        selectedDangerLevel: $selectedDangerLevel,
                        tags: $tags
                    )
                    .tag(1)
                    
                    // Step 3: Photos
                    PhotosStep(
                        selectedPhotos: $selectedPhotos,
                        photoImages: $photoImages
                    )
                    .tag(2)
                    
                    // Step 4: Location
                    LocationStep(
                        locationString: $locationString,
                        isGettingLocation: $isGettingLocation
                    )
                    .tag(3)
                    
                    // Step 5: Review
                    ReviewStep(
                        title: title,
                        description: description,
                        category: selectedCategory,
                        dangerLevel: selectedDangerLevel,
                        tags: tags,
                        photoImages: photoImages,
                        location: locationString
                    )
                    .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Navigation Buttons
                NavigationButtons(
                    currentStep: $currentStep,
                    totalSteps: steps.count,
                    canProceed: canProceedToNextStep(),
                    isSubmitting: $isSubmitting,
                    onSubmit: submitLocation
                )
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Submit Location")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Success!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    resetForm()
                }
            } message: {
                Text("Your location has been submitted for review. It will appear on the map once approved.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { 
                    dataManager.errorMessage = nil
                }
            } message: {
                Text(dataManager.errorMessage ?? "An unknown error occurred")
            }
            .alert("Error", isPresented: .constant(dataManager.errorMessage != nil)) {
                Button("OK") {
                    dataManager.errorMessage = nil
                }
            } message: {
                Text(dataManager.errorMessage ?? "Unknown error occurred")
            }
            .onChange(of: dataManager.submissionSuccess) { oldValue, newValue in
                if newValue {
                    isSubmitting = false
                    showSuccessAlert = true
                    dataManager.submissionSuccess = false // Reset the flag
                }
            }
            .onChange(of: dataManager.isLoading) { oldValue, newValue in
                if !newValue && dataManager.errorMessage != nil {
                    isSubmitting = false
                    showErrorAlert = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func canProceedToNextStep() -> Bool {
        switch currentStep {
        case 0:
            return !title.isEmpty && title.count >= 3 && !description.isEmpty && description.count >= 5
        case 1:
            return true
        case 2:
            return true
        case 3:
            return !locationString.isEmpty
        case 4:
            return true
        default:
            return false
        }
    }
    
    private func submitLocation() {
        print("Submit button pressed")
        print("User location: \(locationManager.userLocation?.latitude ?? 0), \(locationManager.userLocation?.longitude ?? 0)")
        print("Location string: \(locationString)")
        print("Authorization status: \(locationManager.authorizationStatus.rawValue)")
        
        // Check if we have valid coordinates
        let latitude: Double
        let longitude: Double
        
        if let userLocation = locationManager.userLocation, 
           userLocation.latitude != 0.0 && userLocation.longitude != 0.0 {
            latitude = userLocation.latitude
            longitude = userLocation.longitude
            print("Using user location: \(latitude), \(longitude)")
        } else {
            // Try to request location one more time
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startLocationUpdates()
                dataManager.errorMessage = "Getting your location. Please try again in a moment."
                return
            } else {
                // For demo purposes, use coordinates based on the location string or default
                latitude = 42.6977  // Sofia, Bulgaria coordinates as a reasonable default
                longitude = 23.3219
                print("Using default Bulgaria location: \(latitude), \(longitude)")
            }
        }
        
        print("Submitting location with coordinates: \(latitude), \(longitude)")
        isSubmitting = true
        
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        dataManager.submitLocation(
            title: title,
            description: description,
            latitude: latitude,
            longitude: longitude,
            address: locationString.isEmpty ? "Lat: \(latitude), Lng: \(longitude)" : locationString,
            category: selectedCategory,
            dangerLevel: selectedDangerLevel,
            tags: tagArray,
            images: photoImages
        )
    }
    
    private func resetForm() {
        currentStep = 0
        title = ""
        description = ""
        selectedCategory = .other
        selectedDangerLevel = .safe
        tags = ""
        selectedPhotos = []
        photoImages = []
        locationString = ""
    }
}

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.orange : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    if step < totalSteps - 1 {
                        Rectangle()
                            .fill(step < currentStep ? Color.orange : Color.gray)
                            .frame(height: 2)
                    }
                }
            }
            
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct BasicInfoStep: View {
    @Binding var title: String
    @Binding var description: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tell us about this place")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("e.g., Abandoned Hospital (minimum 3 characters)", text: $title)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    if !title.isEmpty && title.count < 3 {
                        Text("Title must be at least 3 characters long")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Describe what makes this place special... (minimum 5 characters)", text: $description, axis: .vertical)
                        .textFieldStyle(CustomTextFieldStyle())
                        .lineLimit(4...8)
                    
                    if !description.isEmpty && description.count < 5 {
                        Text("Description must be at least 5 characters long")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct DetailsStep: View {
    @Binding var selectedCategory: LocationCategory
    @Binding var selectedDangerLevel: DangerLevel
    @Binding var tags: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add more details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(LocationCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Safety Level")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        ForEach(DangerLevel.allCases, id: \.self) { level in
                            DangerButton(
                                level: level,
                                isSelected: selectedDangerLevel == level
                            ) {
                                selectedDangerLevel = level
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags (comma separated)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("e.g., creepy, photography, urban exploration", text: $tags)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct PhotosStep: View {
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var photoImages: [UIImage]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add photos")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Photos help others discover this location. Add up to 5 photos.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [10]))
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Image(systemName: "photo.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("Tap to add photos")
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                if !photoImages.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(0..<photoImages.count, id: \.self) { index in
                            Image(uiImage: photoImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                                .cornerRadius(12)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
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
}

struct LocationStep: View {
    @Binding var locationString: String
    @EnvironmentObject var locationManager: LocationManager
    @Binding var isGettingLocation: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Where is this place?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address or Location Description")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("e.g., 123 Main St, City, State", text: $locationString)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                Button(action: {
                    print("Use Current Location button pressed")
                    print("Current authorization status: \(locationManager.authorizationStatus.rawValue)")
                    
                    switch locationManager.authorizationStatus {
                    case .notDetermined:
                        locationManager.requestLocationPermission()
                        locationString = "Requesting location permission..."
                    case .denied, .restricted:
                        locationString = "Location access denied. Please enable in Settings."
                    case .authorizedWhenInUse, .authorizedAlways:
                        if let location = locationManager.userLocation {
                            locationString = "Lat: \(String(format: "%.6f", location.latitude)), Lng: \(String(format: "%.6f", location.longitude))"
                            print("Using location: \(location)")
                        } else {
                            isGettingLocation = true
                            locationManager.startLocationUpdates()
                            locationString = "Getting location..."
                            
                            // Check for location update after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                isGettingLocation = false
                                if let updatedLocation = locationManager.userLocation {
                                    locationString = "Lat: \(String(format: "%.6f", updatedLocation.latitude)), Lng: \(String(format: "%.6f", updatedLocation.longitude))"
                                } else if locationString == "Getting location..." {
                                    locationString = "Unable to get location. Please enter manually."
                                }
                            }
                        }
                    @unknown default:
                        break
                    }
                }) {
                    HStack {
                        if isGettingLocation {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.orange)
                        }
                        Text(isGettingLocation ? "Getting Location..." : "Use Current Location")
                    }
                }
                .foregroundColor(.orange)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct ReviewStep: View {
    let title: String
    let description: String
    let category: LocationCategory
    let dangerLevel: DangerLevel
    let tags: String
    let photoImages: [UIImage]
    let location: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review your submission")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 16) {
                    ReviewItem(title: "Title", value: title)
                    ReviewItem(title: "Category", value: category.rawValue)
                    ReviewItem(title: "Safety Level", value: dangerLevel.rawValue)
                    ReviewItem(title: "Description", value: description)
                    ReviewItem(title: "Tags", value: tags)
                    ReviewItem(title: "Location", value: location)
                    
                    if !photoImages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photos (\(photoImages.count))")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(0..<photoImages.count, id: \.self) { index in
                                        Image(uiImage: photoImages[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct ReviewItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(value.isEmpty ? "Not specified" : value)
                .font(.body)
                .foregroundColor(.gray)
        }
    }
}

struct NavigationButtons: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let canProceed: Bool
    @Binding var isSubmitting: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .foregroundColor(.gray)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
            }
            
            Spacer()
            
            if currentStep < totalSteps - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .foregroundColor(canProceed ? .black : .gray)
                .padding()
                .background(canProceed ? Color.orange : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .disabled(!canProceed)
            } else {
                Button(action: onSubmit) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit")
                    }
                }
                .foregroundColor(.black)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
                .disabled(isSubmitting || !canProceed)
            }
        }
    }
}

struct CategoryButton: View {
    let category: LocationCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.rawValue)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .black : .white)
            .padding()
            .background(isSelected ? Color.orange : Color.gray.opacity(0.2))
            .cornerRadius(12)
            .frame(maxWidth: .infinity)
        }
    }
}

struct DangerButton: View {
    let level: DangerLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(level.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding()
                .background(isSelected ? levelColor : Color.gray.opacity(0.2))
                .cornerRadius(12)
                .frame(maxWidth: .infinity)
        }
    }
    
    private var levelColor: Color {
        switch level {
        case .safe: return .green
        case .caution: return .yellow
        case .dangerous: return .red
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            .foregroundColor(.white)
    }
}

#Preview {
    SubmitLocationView()
        .environmentObject(DataManager())
        .environmentObject(LocationManager())
}
