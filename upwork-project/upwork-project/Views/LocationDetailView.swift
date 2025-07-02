//
//  LocationDetailView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI

struct LocationDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    let location: AbandonedLocation
    let isAdminReview: Bool
    @State private var showFullImage = false
    @State private var selectedImageIndex = 0
    @Environment(\.dismiss) private var dismiss
    
    // Dynamic state for like/bookmark
    @State private var isLiked: Bool
    @State private var isBookmarked: Bool
    @State private var likeCount: Int
    @State private var bookmarkCount: Int
    
    init(location: AbandonedLocation, isAdminReview: Bool = false) {
        self.location = location
        self.isAdminReview = isAdminReview
        // Initialize dynamic state with location's current values
        self._isLiked = State(initialValue: location.isLiked)
        self._isBookmarked = State(initialValue: location.isBookmarked)
        self._likeCount = State(initialValue: location.likeCount)
        self._bookmarkCount = State(initialValue: location.bookmarkCount)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Debug info at the top
                    if isAdminReview {
                        Text("Admin Review Mode")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Text("DEBUG: Location ID: \(location.id), Title: '\(location.title)'")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .onAppear {
                            print("LocationDetailView: Showing location - ID: \(location.id), Title: '\(location.title)', Images: \(location.displayImages.count)")
                        }
                    
                    // Image Carousel
                    if !location.displayImages.isEmpty {
                        ImageCarousel(images: location.displayImages, selectedIndex: $selectedImageIndex)
                            .frame(height: 180)
                            .onTapGesture {
                                showFullImage = true
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Title and Category
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Image(systemName: location.category.icon)
                                    Text(location.category.rawValue)
                                }
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            DangerLevelBadge(level: location.danger)
                        }
                        
                        // Location
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.orange)
                            Text(location.address)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Description
                        Text(location.description)
                            .font(.body)
                            .foregroundColor(.white)
                            .lineLimit(nil)
                        
                        // Tags
                        TagsView(tags: location.tags)
                        
                        // Stats
                        HStack(spacing: 20) {
                            StatView(icon: "heart.fill", value: "\(likeCount)", color: .red)
                            StatView(icon: "bookmark.fill", value: "\(bookmarkCount)", color: .orange)
                            StatView(icon: "person.fill", value: location.submittedByUsername ?? (location.submittedBy.map { "User \($0)" } ?? "Unknown"), color: .blue)
                            StatView(icon: "calendar", value: formatDate(location.submissionDate), color: .green)
                        }
                        
                        // Action Buttons
                        if isAdminReview {
                            // Admin Review Buttons
                            VStack(spacing: 12) {
                                Text("Admin Review")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                
                                HStack(spacing: 16) {
                                    Button(action: {
                                        dataManager.rejectLocation(location.id)
                                        dismiss()
                                    }) {
                                        HStack {
                                            Image(systemName: "xmark.circle.fill")
                                            Text("Reject")
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(10)
                                    }
                                    
                                    Button(action: {
                                        dataManager.approveLocation(location.id)
                                        dismiss()
                                    }) {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("Approve")
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.top)
                        } else {
                            // Regular Action Buttons
                            HStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    ActionButton(
                                        icon: isBookmarked ? "bookmark.fill" : "bookmark",
                                        title: "Bookmark",
                                        color: isBookmarked ? .orange : .gray
                                    ) {
                                        toggleBookmark()
                                    }
                                    
                                    Text("\(bookmarkCount)")
                                        .font(.caption)
                                        .foregroundColor(isBookmarked ? .orange : .gray)
                                }
                                
                                VStack(spacing: 8) {
                                    ActionButton(
                                        icon: isLiked ? "heart.fill" : "heart",
                                        title: "Like",
                                        color: isLiked ? .red : .gray
                                    ) {
                                        toggleLike()
                                    }
                                    
                                    Text("\(likeCount)")
                                        .font(.caption)
                                        .foregroundColor(isLiked ? .red : .gray)
                                }
                                
                                VStack(spacing: 8) {
                                    ActionButton(
                                        icon: "square.and.arrow.up",
                                        title: "Share",
                                        color: .blue
                                    ) {
                                        // Share functionality
                                    }
                                    
                                    Text(" ")
                                        .font(.caption)
                                        .foregroundColor(.clear)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .fullScreenCover(isPresented: $showFullImage) {
            FullScreenImageView(images: location.displayImages, selectedIndex: $selectedImageIndex)
        }
        .onAppear {
            // Sync with current location state from data manager
            syncWithDataManager()
        }
        .onChange(of: dataManager.locations) { _, _ in
            // Update state when locations are refreshed
            syncWithDataManager()
        }
        .onChange(of: dataManager.errorMessage) { _, errorMessage in
            // Show error message if like/bookmark operations fail
            if let error = errorMessage, !error.isEmpty {
                // Here you could show a toast or alert if needed
                print("LocationDetailView: Error occurred: \(error)")
            }
        }
    }
    
    private func syncWithDataManager() {
        // Find the updated location in the data manager and sync state
        if let updatedLocation = dataManager.locations.first(where: { $0.id == location.id }) {
            // Only update if values are actually different to avoid unnecessary UI updates
            if isLiked != updatedLocation.isLiked {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLiked = updatedLocation.isLiked
                }
            }
            
            if isBookmarked != updatedLocation.isBookmarked {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBookmarked = updatedLocation.isBookmarked
                }
            }
            
            if likeCount != updatedLocation.likeCount {
                withAnimation(.easeInOut(duration: 0.2)) {
                    likeCount = updatedLocation.likeCount
                }
            }
            
            if bookmarkCount != updatedLocation.bookmarkCount {
                withAnimation(.easeInOut(duration: 0.2)) {
                    bookmarkCount = updatedLocation.bookmarkCount
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func toggleLike() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate the change
        withAnimation(.easeInOut(duration: 0.2)) {
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }
        
        // Call API
        dataManager.toggleLike(for: location.id)
    }
    
    private func toggleBookmark() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate the change
        withAnimation(.easeInOut(duration: 0.2)) {
            isBookmarked.toggle()
            bookmarkCount += isBookmarked ? 1 : -1
        }
        
        // Call API
        dataManager.toggleBookmark(for: location.id)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct ImageCarousel: View {
    let images: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(0..<images.count, id: \.self) { index in
                CachedAsyncImage(url: images[index]) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.title)
                        )
                }
                .clipped()
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
    }
}

struct DangerLevelBadge: View {
    let level: DangerLevel
    
    var body: some View {
        Text(level.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(badgeColor)
            .foregroundColor(.black)
            .cornerRadius(12)
    }
    
    private var badgeColor: Color {
        switch level {
        case .safe:
            return .green
        case .caution:
            return .yellow
        case .dangerous:
            return .red
        }
    }
}

struct TagsView: View {
    let tags: [String]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }
        }
    }
}

struct StatView: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var isActive: Bool {
        color != .gray
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                Text(title)
                    .font(.caption)
                    .fontWeight(isActive ? .semibold : .regular)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(isActive ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(isActive ? 0.5 : 0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

struct FullScreenImageView: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(0..<images.count, id: \.self) { index in
                    CachedAsyncImage(url: images[index]) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            
            VStack {
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    LocationDetailView(location: AbandonedLocation(
        id: 1,
        title: "Sample Location",
        description: "A sample abandoned location for preview",
        latitude: 40.7128,
        longitude: -74.0060,
        address: "123 Sample St",
        tags: ["sample", "preview"],
        images: [],
        submittedBy: 1,
        submissionDate: Date(),
        likeCount: 42,
        bookmarkCount: 15,
        isBookmarked: false,
        isApproved: true,
        categoryName: "Hospital",
        dangerLevel: "Safe"
    ))
    .environmentObject(DataManager())
}
