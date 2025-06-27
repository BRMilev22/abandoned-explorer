//
//  FeedView.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedLocation: AbandonedLocation?
    @State private var showLocationDetail = false
    @State private var searchText = ""
    @State private var selectedCategory: LocationCategory?
    
    // Helper to validate location data before showing detail
    private func isValidLocationData(_ location: AbandonedLocation) -> Bool {
        let isValid = !location.title.isEmpty && location.id > 0
        if !isValid {
            print("FeedView: Invalid location data - ID: \(location.id), Title: '\(location.title)'")
        }
        return isValid
    }
    
    var filteredLocations: [AbandonedLocation] {
        var locations = dataManager.getRecentLocations()
        
        if !searchText.isEmpty {
            locations = locations.filter { location in
                location.title.localizedCaseInsensitiveContains(searchText) ||
                location.description.localizedCaseInsensitiveContains(searchText) ||
                location.tags.joined().localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let category = selectedCategory {
            locations = locations.filter { $0.category == category }
        }
        
        return locations
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Header
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    CategoryFilter(selectedCategory: $selectedCategory)
                }
                .padding()
                .background(Color.black)
                
                // Feed List
                if dataManager.isLoading {
                    Spacer()
                    ProgressView("Loading locations...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .foregroundColor(.white)
                    Spacer()
                } else if filteredLocations.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No locations found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        if !searchText.isEmpty || selectedCategory != nil {
                            Text("Try adjusting your search or filters")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredLocations) { location in
                                FeedItemView(location: location) {
                                    print("FeedView: Location tapped - ID: \(location.id), Title: '\(location.title)'")
                                    // Ensure we have valid location data before showing detail
                                    if isValidLocationData(location) {
                                        print("FeedView: Setting selectedLocation to: \(location.title)")
                                        selectedLocation = location
                                        print("FeedView: Setting showLocationDetail to true")
                                        showLocationDetail = true
                                        print("FeedView: After setting - selectedLocation: \(selectedLocation?.title ?? "nil"), showLocationDetail: \(showLocationDetail)")
                                    } else {
                                        print("FeedView: Cannot show detail - invalid location data")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Recent Discoveries")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .refreshable {
                dataManager.loadAllLocations()
            }
        }
        .fullScreenCover(isPresented: $showLocationDetail) {
            if let location = selectedLocation, isValidLocationData(location) {
                LocationDetailModalView(location: location, selectedLocation: $selectedLocation)
            } else {
                // Fallback view if location data is invalid
                VStack(spacing: 20) {
                    ProgressView("Loading location details...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    
                    Button("Close") {
                        showLocationDetail = false
                        selectedLocation = nil
                    }
                    .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .onAppear {
            // Load locations if not already loaded
            if dataManager.locations.isEmpty {
                dataManager.loadAllLocations()
            }
        }
        .onChange(of: selectedLocation) { _, newValue in
            print("FeedView: selectedLocation changed to: \(newValue?.title ?? "nil")")
        }
        .onChange(of: showLocationDetail) { _, newValue in
            print("FeedView: showLocationDetail changed to: \(newValue)")
        }
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search locations..."
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = context.coordinator
        
        // Customize appearance for dark theme
        searchBar.barTintColor = .black
        searchBar.searchTextField.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        searchBar.searchTextField.textColor = .white
        searchBar.searchTextField.leftView?.tintColor = .orange
        
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        let parent: SearchBar
        
        init(_ parent: SearchBar) {
            self.parent = parent
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }
    }
}

struct CategoryFilter: View {
    @Binding var selectedCategory: LocationCategory?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                
                ForEach(LocationCategory.allCases, id: \.self) { category in
                    FilterChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(20)
        }
    }
}

struct FeedItemView: View {
    @EnvironmentObject var dataManager: DataManager
    let location: AbandonedLocation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Image
                if let firstImage = location.displayImages.first {
                    CachedAsyncImage(url: firstImage) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            )
                    }
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        // Image count indicator
                        alignment: .topTrailing
                    ) {
                        if location.displayImages.count > 1 {
                            HStack(spacing: 2) {
                                Image(systemName: "photo.stack")
                                Text("\(location.displayImages.count)")
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(8)
                        }
                    }
                } else {
                    // Placeholder when no images
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.title)
                                Text("No Image")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                        .frame(height: 200)
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title and Category
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            
                            HStack {
                                Image(systemName: location.category.icon)
                                Text(location.category.rawValue)
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        DangerLevelBadge(level: location.danger)
                    }
                    
                    // Description
                    Text(location.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Tags (first 3)
                    if !location.tags.isEmpty {
                        HStack {
                            ForEach(Array(location.tags.prefix(3)), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                            if location.tags.count > 3 {
                                Text("+\(location.tags.count - 3)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Stats and Actions
                    HStack {
                        HStack(spacing: 16) {
                            // Like count
                            StatView(icon: "heart.fill", value: "\(location.likeCount)", color: .red)
                            
                            // Bookmark count
                            StatView(icon: "bookmark.fill", value: "\(location.bookmarkCount)", color: .orange)
                            
                            // Submitted by info
                            if let username = location.submittedByUsername {
                                StatView(icon: "person.fill", value: username, color: .blue)
                            } else if let submittedBy = location.submittedBy {
                                StatView(icon: "person.fill", value: "User \(submittedBy)", color: .blue)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            // Bookmark button
                            Button(action: {
                                dataManager.toggleBookmark(for: location.id)
                            }) {
                                Image(systemName: location.isBookmarked ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(location.isBookmarked ? .orange : .gray)
                                    .font(.title2)
                            }
                            
                            // Like button - check if user has liked this location
                            Button(action: {
                                dataManager.toggleLike(for: location.id)
                            }) {
                                Image(systemName: location.isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(location.isLiked ? .red : .gray)
                                    .font(.title2)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.05))
                .shadow(radius: 4)
        )
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FeedView()
        .environmentObject(DataManager())
}
