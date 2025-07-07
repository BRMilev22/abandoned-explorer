import SwiftUI
import CoreLocation
import Combine
import AVKit
import AVFoundation

// MARK: - Combined Media Types
enum MediaItem: Hashable {
    case image(LocationImage)
    case video(LocationVideo)
    
    var url: String {
        switch self {
        case .image(let img): return img.imageUrl
        case .video(let vid): return vid.videoUrl
        }
    }
    
    var thumbnailUrl: String? {
        switch self {
        case .image(let img): return img.thumbnailUrl
        case .video(let vid): return vid.thumbnailUrl
        }
    }
    
    var isVideo: Bool {
        switch self {
        case .image: return false
        case .video: return true
        }
    }
}

// MARK: - Video Player View with Play Button
struct VideoPlayerView: View {
    let url: URL
    @State private var isPlaying = false
    @State private var showPlayer = false
    
    var body: some View {
        ZStack {
            // Video thumbnail/preview
            Rectangle()
                .fill(Color.black)
                            .overlay(
                SwiftUI.Group {
                    if showPlayer {
                        VideoController(url: url, isPlaying: $isPlaying)
                    } else {
                        // Play button overlay
                        VStack(spacing: 12) {
                            Button(action: {
                                showPlayer = true
                                isPlaying = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.7))
                                        .frame(width: 80, height: 80)
                                    
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(.white)
                                        .offset(x: 3) // Slight offset to center visually
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("Tap to play video")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Internal Video Controller
struct VideoController: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPlaying: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspectFill
        
        // Don't auto-play - wait for user interaction
        if isPlaying {
            player.play()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if isPlaying {
            uiViewController.player?.play()
        } else {
            uiViewController.player?.pause()
        }
    }
}

// MARK: - Fullscreen Image View
struct FullscreenImageView: View {
    let mediaItems: [MediaItem]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    @State private var currentScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !mediaItems.isEmpty {
                TabView(selection: $selectedIndex) {
                    ForEach(0..<mediaItems.count, id: \.self) { index in
                        ZStack {
                            // Only show images in fullscreen mode, skip videos
                            if !mediaItems[index].isVideo {
                                CachedAsyncImage(url: mediaItems[index].url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .scaleEffect(currentScale)
                                        .offset(currentOffset)
                                        .gesture(
                                            SimultaneousGesture(
                                                // Magnification gesture for pinch to zoom
                                                MagnificationGesture()
                                                    .onChanged { value in
                                                        currentScale = value
                                                    }
                                                    .onEnded { _ in
                                                        withAnimation(.spring()) {
                                                            if currentScale < 1.0 {
                                                                currentScale = 1.0
                                                                currentOffset = .zero
                                                            } else if currentScale > 3.0 {
                                                                currentScale = 3.0
                                                            }
                                                        }
                                                    },
                                                // Drag gesture for panning when zoomed
                                                DragGesture()
                                                    .onChanged { value in
                                                        if currentScale > 1.0 {
                                                            currentOffset = value.translation
                                                        }
                                                    }
                                                    .onEnded { _ in
                                                        if currentScale <= 1.0 {
                                                            withAnimation(.spring()) {
                                                                currentOffset = .zero
                                                            }
                                                        }
                                                    }
                                            )
                                        )
                                        .onTapGesture(count: 2) {
                                            // Double tap to zoom
                                            withAnimation(.spring()) {
                                                if currentScale == 1.0 {
                                                    currentScale = 2.0
                                                } else {
                                                    currentScale = 1.0
                                                    currentOffset = .zero
                                                }
                                            }
                                        }
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            VStack(spacing: 12) {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(1.5)
                                                Text("Loading image...")
                                                    .font(.subheadline)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        )
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                // For videos, show a message
                                VStack(spacing: 20) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text("Video content")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Videos cannot be displayed in fullscreen mode")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Page indicators
                if mediaItems.count > 1 {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, mediaItem in
                                Circle()
                                    .fill(selectedIndex == index ? Color.white : Color.white.opacity(0.5))
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        // Add a small video icon for video items
                                        mediaItem.isVideo ? 
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 5))
                                            .foregroundColor(.black)
                                        : nil
                                    )
                            }
                        }
                        .padding(.bottom, 50)
                    }
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                        // Reset zoom when closing
                        currentScale = 1.0
                        currentOffset = .zero
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
        .onDisappear {
            // Reset zoom when view disappears
            currentScale = 1.0
            currentOffset = .zero
        }
    }
}

struct LocationDetailModalView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var locationManager: LocationManager
    let location: AbandonedLocation
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: AbandonedLocation?
    
    // Dynamic state from API
    @State private var locationDetails: LocationDetails?
    @State private var comments: [Comment] = []
    @State private var isLoadingDetails = true
    @State private var isLoadingComments = true
    @State private var errorMessage: String?
    
    // User interface state
    @State private var selectedImageIndex = 0
    @State private var showingShareSheet = false
    @State private var chatMessage = ""

    @State private var commentOffset = 0
    @State private var hasMoreComments = true
    @State private var isPostingComment = false
    @State private var replyingToComment: Comment?
    @State private var showingReplies: Set<Int> = []
    @State private var likedComments: Set<Int> = []
    @State private var hasTrackedView = false
    private static var trackedLocationIds = Set<Int>()
    private static var globalLikedComments = Set<Int>()
    @State private var showingFullscreenImage = false
    @State private var likeAnimation = false
    @State private var bookmarkAnimation = false
    @State private var nearbyLocations: [AbandonedLocation] = []
    @State private var isLoadingNearby = false
    
    // Cancellables for API calls
    @State private var cancellables = Set<AnyCancellable>()
    
    var distanceText: String {
        guard let userLocation = locationManager.userLocation else {
            return "Distance unknown"
        }
        
        let locationCoordinate = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let userLocationCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let distance = locationCoordinate.distance(from: userLocationCL)
        
        let distanceInMiles = distance * 0.000621371
        return String(format: "%.1f mi", distanceInMiles)
    }
    
    var shareText: String {
        return "Check out this abandoned location: \(locationDetails?.title ?? location.title)\n\(locationDetails?.description ?? location.description)\nLocation: \(locationDetails?.address ?? location.address)"
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Tap to dismiss keyboard
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            

            

            
            if isLoadingDetails {
                VStack {
                    ProgressView("Loading...")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Text("Error loading location")
                        .foregroundColor(.white)
                        .font(.title2)
                    
                    Text(error)
                        .foregroundColor(.gray)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        loadLocationDetails()
                    }
                    .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let details = locationDetails {
                VStack(spacing: 0) {
                    // Scrollable content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Hero Image/Video Section
                            heroMediaSection(details: details)
                            
                            // Main Content
                            VStack(alignment: .leading, spacing: 0) {
                                // Modern header with location info
                                modernHeaderSection(details: details)
                                
                                // Modern stats with animations
                                modernStatsSection(details: details)
                                
                                // Description section
                                modernDescriptionSection(details: details)
                                
                                // Actual nearby locations
                                modernNearbySection
                                
                                // Comments section
                                modernCommentsSection
                            }
                            .padding(.bottom, 20) // Reduced padding since bottom bar is now separate
                        }
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                hideKeyboard()
                            }
                    )
                    
                    // Fixed bottom bar (not floating)
                    modernBottomBar(details: details)
                }
            } else {
                // Fallback UI using basic location data
                VStack(spacing: 20) {
                    Text("Basic Location View")
                        .foregroundColor(.white)
                        .font(.title)
                    
                    Text("Title: \(location.title)")
                        .foregroundColor(.white)
                        .font(.title2)
                    
                    Text("Description: \(location.description)")
                        .foregroundColor(.gray)
                        .font(.body)
                    
                    Text("Address: \(location.address)")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    Button("Retry Loading Details") {
                        loadLocationDetails()
                    }
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
            
            // Top navigation overlay
            VStack {
                topNavigationBar
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
        .fullScreenCover(isPresented: $showingFullscreenImage) {
            if let details = locationDetails {
                FullscreenImageView(
                    mediaItems: details.images.map { .image($0) } + details.videos.map { .video($0) },
                    selectedIndex: $selectedImageIndex,
                    isPresented: $showingFullscreenImage
                )
            }
        }
        .onAppear {
            print("🎬 LocationDetailModalView appeared for location: \(location.title) (ID: \(location.id))")
            
            // Check for cached details first for instant loading
            if let cachedDetails = dataManager.getCachedLocationDetails(locationId: location.id) {
                print("⚡ Using cached location details for instant load")
                locationDetails = cachedDetails
                isLoadingDetails = false
                
                // Still load fresh data in background, but no rush
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    await loadLocationDetailsAsync()
                }
            } else {
                // Instant UI with minimal object creation
                locationDetails = createMinimalLocationDetails()
                isLoadingDetails = false
                
                // Load fresh details immediately
                Task {
                    await loadLocationDetailsAsync()
                }
            }
            
            // Progressive loading for other data
            Task {
                // Load comments with delay to avoid blocking
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay
                await MainActor.run {
                    loadComments()
                }
                
                // Load secondary data with more delay
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                await MainActor.run {
                    trackViewIfNeeded()
                    loadNearbyLocations()
                    
                    // Load globally liked comments
                    likedComments = Self.globalLikedComments
                }
            }
        }
    }
    
    // MARK: - Hero Media Section
    private func heroMediaSection(details: LocationDetails) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Combine images and videos into a single media array
                let mediaItems: [MediaItem] = details.images.map { .image($0) } + details.videos.map { .video($0) }
                
                if !mediaItems.isEmpty {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(0..<mediaItems.count, id: \.self) { index in
                            MediaItemView(mediaItem: mediaItems[index])
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .onTapGesture {
                                    showingFullscreenImage = true
                                }
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 40))
                                Text("No media available")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        )
                }
                
                // Page indicators (bottom center)
                if mediaItems.count > 1 {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, mediaItem in
                                Circle()
                                    .fill(selectedImageIndex == index ? Color.white : Color.white.opacity(0.5))
                                    .frame(width: 8, height: 8)
                                    .overlay(
                                        // Add a small video icon for video items
                                        mediaItem.isVideo ? 
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 4))
                                            .foregroundColor(.black)
                                        : nil
                                    )
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                

                
                // Fullscreen button (bottom right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingFullscreenImage = true
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.white)
                                .font(.title3)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.3) // 30% of screen height
        .clipped()
    }
    

    

    

    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.title2)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Button(action: {
                // More options
            }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.white)
                    .font(.title2)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }
    
    // MARK: - Modern Header Section
    private func modernHeaderSection(details: LocationDetails) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Location info with glass morphism
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(distanceText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let address = details.address {
                        Text(address)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Category icon with modern styling
                if let categoryName = details.categoryName {
                    HStack(spacing: 6) {
                        Image(systemName: categoryIconName(for: categoryName))
                            .font(.system(size: 14, weight: .medium))
                        Text(categoryName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Material.ultraThinMaterial)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Material.ultraThinMaterial.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Title with modern typography
            VStack(alignment: .leading, spacing: 8) {
                Text(details.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                if let description = details.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Modern Stats Section
    private func modernStatsSection(details: LocationDetails) -> some View {
        VStack(spacing: 20) {
            // Top row - Views and Share
            HStack {
                // Views with modern counter
                StatCard(
                    icon: "eye.fill",
                    count: details.viewsCount,
                    label: "Views",
                    color: .blue,
                    isViewsCard: true
                )
                
                Spacer()
                
                // Share button with modern design
                Button(action: {
                    showingShareSheet = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Material.ultraThinMaterial)
                            .clipShape(Circle())
                        
                        Text("Share")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Bottom row - Interactive buttons in a clean grid
            HStack(spacing: 12) {
                // Interactive Like button with animation
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        likeAnimation.toggle()
                    }
                    toggleLike()
                }) {
                    ModernInteractionCard(
                        icon: details.userInteractions.isLiked ? "heart.fill" : "heart",
                        count: details.likesCount,
                        label: "Likes",
                        color: details.userInteractions.isLiked ? .red : .white,
                        isActive: details.userInteractions.isLiked
                    )
                    .scaleEffect(likeAnimation ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: details.userInteractions.isLiked)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Interactive Bookmark button with animation
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        bookmarkAnimation.toggle()
                    }
                    toggleBookmark()
                }) {
                    ModernInteractionCard(
                        icon: details.userInteractions.isBookmarked ? "bookmark.fill" : "bookmark",
                        count: details.bookmarksCount,
                        label: "Bookmarks",
                        color: details.userInteractions.isBookmarked ? .orange : .white,
                        isActive: details.userInteractions.isBookmarked
                    )
                    .scaleEffect(bookmarkAnimation ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: details.userInteractions.isBookmarked)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Comments
                ModernInteractionCard(
                    icon: "bubble.fill",
                    count: details.commentsCount,
                    label: "Comments",
                    color: .white,
                    isActive: false
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    

    
    // MARK: - Modern Description Section
    private func modernDescriptionSection(details: LocationDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Description
            if let description = details.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Description")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                    
                    Text(description)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(nil)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Material.ultraThinMaterial.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                }
            }
            
            // Tags with modern design
            if !details.tags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(details.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Material.ultraThinMaterial)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            // Additional info cards
            VStack(spacing: 12) {
                if let dangerLevel = details.dangerLevel {
                    InfoCard(
                        icon: "shield.fill",
                        title: "Safety Level",
                        subtitle: dangerLevel,
                        color: dangerLevelColor(details.dangerColor)
                    )
                    .padding(.horizontal, 16)
                }
                
                if let submittedBy = details.submittedByUsername {
                    InfoCard(
                        icon: "person.fill",
                        title: "Submitted by",
                        subtitle: submittedBy,
                        color: .orange
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Legacy Content Section (keeping for reference)
    private func modernContentSection(details: LocationDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Tags with modern design
            if !details.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(details.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Material.ultraThinMaterial)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Additional info cards
            if let dangerLevel = details.dangerLevel {
                InfoCard(
                    icon: "shield.fill",
                    title: "Safety Level",
                    subtitle: dangerLevel,
                    color: dangerLevelColor(details.dangerColor)
                )
                .padding(.horizontal, 16)
            }
            
            if let submittedBy = details.submittedByUsername {
                InfoCard(
                    icon: "person.fill",
                    title: "Submitted by",
                    subtitle: submittedBy,
                    color: .orange
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Modern Timeline Section
    private func modernTimelineSection(details: LocationDetails) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Timeline")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(details.timeline.count) events")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            
            LazyVStack(spacing: 12) {
                ForEach(details.timeline, id: \.timestamp) { event in
                    ModernTimelineEvent(event: event)
                }
            }
        }
        .padding(.top, 32)
    }
    
    // MARK: - Modern Nearby Section
    private var modernNearbySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nearby Locations")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isLoadingNearby {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            
            if nearbyLocations.isEmpty && !isLoadingNearby {
                Text("No nearby locations found")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(nearbyLocations) { nearbyLocation in
                            Button(action: {
                                // Navigate to the nearby location
                                print("🔄 Navigating to nearby location: \(nearbyLocation.title)")
                                // Update the selected location which will trigger navigation
                                selectedLocation = nearbyLocation
                                // Dismiss current modal to show the new location
                                dismiss()
                            }) {
                                NearbyLocationCard(location: nearbyLocation, currentLocation: location)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 32)
    }
    
    // MARK: - Advanced Comments Section (TikTok Style)
    private var modernCommentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Comments")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(comments.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            
            if comments.isEmpty && !isLoadingComments {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("No comments yet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Be the first to share your thoughts!")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(comments) { comment in
                        AdvancedCommentView(
                            comment: comment,
                            isLiked: likedComments.contains(comment.id),
                            showReplies: showingReplies.contains(comment.id),
                            onLike: { toggleCommentLike(comment.id) },
                            onReply: { replyingToComment = comment },
                            onToggleReplies: { toggleReplies(for: comment.id) }
                        )
                    }
                    
                    if hasMoreComments {
                        Button("Load more comments") {
                            loadMoreComments()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Material.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
            }
            
            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        }
        .padding(.top, 32)
    }
    
    // MARK: - Advanced Bottom Bar with Reply Support
    private func modernBottomBar(details: LocationDetails) -> some View {
        VStack(spacing: 12) {
            // Reply indicator
            if let replyingTo = replyingToComment {
                HStack {
                    Text("Replying to \(replyingTo.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        replyingToComment = nil
                        hideKeyboard()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Material.ultraThinMaterial.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
            
            HStack(spacing: 16) {
                // Comment input with modern design
                HStack(spacing: 12) {
                    TextField(replyingToComment != nil ? "Add a reply..." : "Add a comment...", text: $chatMessage, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1...3)
                        .onSubmit {
                            if !chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                sendMessage()
                            }
                        }
                    
                    // Send button with gradient
                    Button(action: sendMessage) {
                        SwiftUI.Group {
                            if isPostingComment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .background(
                            SwiftUI.Group {
                                if chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Circle()
                                        .fill(Material.ultraThinMaterial.opacity(0.5))
                                } else {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.orange, .red.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                }
                            }
                        )
                        .clipShape(Circle())
                        .scaleEffect(chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3), value: chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .disabled(chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPostingComment)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Material.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(.black.opacity(0.95))
                .overlay(
                    Rectangle()
                        .fill(Material.ultraThinMaterial.opacity(0.1))
                )
        )
    }
    
    // MARK: - Helper Methods
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Fast minimal object creation for instant UI
    private func createMinimalLocationDetails() -> LocationDetails {
        return LocationDetails(
            id: location.id,
            title: location.title,
            description: location.description,
            latitude: location.latitude,
            longitude: location.longitude,
            address: location.address,
            viewsCount: 0,
            likesCount: location.likeCount ?? 0,
            bookmarksCount: location.bookmarkCount ?? 0,
            commentsCount: 0,
            submissionDate: "2024-01-01T00:00:00Z",
            featured: false,
            categoryName: location.categoryName,
            categoryIcon: nil,
            categoryColor: nil,
            dangerLevel: location.dangerLevel,
            dangerColor: nil,
            dangerDescription: nil,
            riskLevel: nil,
            submittedByUsername: location.submittedByUsername,
            submittedByAvatar: nil,
            images: location.images.map { LocationImage(imageUrl: $0, thumbnailUrl: nil, caption: nil) },
            videos: location.videos.map { LocationVideo(videoUrl: $0, thumbnailUrl: nil, caption: nil) },
            tags: location.tags,
            timeline: [],
            userInteractions: UserInteractions(
                isLiked: location.isLiked ?? false,
                isBookmarked: location.isBookmarked ?? false,
                hasVisited: false
            )
        )
    }
    
    private func loadLocationDetails() {
        print("🎬 LocationDetailModalView: Starting to load details for location ID: \(location.id)")
        
        // Don't set loading to true since we already have fallback content
        // This prevents UI blocking and provides instant feedback
        
        dataManager.apiService.getLocationDetails(locationId: location.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    print("🎬 LocationDetailModalView: API call completed")
                    if case .failure(let error) = completion {
                        print("❌ Failed to load location details: \(error.localizedDescription)")
                        // Don't show error immediately - user already sees content
                        // Only show error if they try to interact with incomplete data
                    }
                },
                receiveValue: { response in
                    print("✅ Location details loaded: \(response.location.title)")
                    
                    // Update with fresh data smoothly
                    withAnimation(.easeInOut(duration: 0.3)) {
                        locationDetails = response.location
                    }
                    
                    // Cache the fresh details for future use
                    dataManager.cacheLocationDetails(response.location)
                    
                    // Preload images in background (non-blocking)
                    Task.detached(priority: .background) {
                        let mediaUrls = response.location.images.map { $0.imageUrl } + 
                                       response.location.videos.compactMap { $0.thumbnailUrl }
                        if !mediaUrls.isEmpty {
                            ImageCache.shared.preloadImages(urls: mediaUrls, limitToWiFi: false)
                        }
                    }
                    
                    print("🎬 LocationDetailModalView: Updated with fresh API data")
                }
            )
            .store(in: &cancellables)
    }
    
    // Async version for better performance
    private func loadLocationDetailsAsync() async {
        print("🎬 LocationDetailModalView: Starting async load for location ID: \(location.id)")
        
        do {
            let response = try await withCheckedThrowingContinuation { continuation in
                dataManager.apiService.getLocationDetails(locationId: location.id)
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { response in
                            continuation.resume(returning: response)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            print("✅ Async location details loaded: \(response.location.title)")
            
            // Update UI smoothly on main actor
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    locationDetails = response.location
                }
                // Cache the fresh details for future use
                dataManager.cacheLocationDetails(response.location)
            }
            
            // Preload images in background (non-blocking)
            Task.detached(priority: .background) {
                let mediaUrls = response.location.images.map { $0.imageUrl } + 
                               response.location.videos.compactMap { $0.thumbnailUrl }
                if !mediaUrls.isEmpty {
                    ImageCache.shared.preloadImages(urls: mediaUrls, limitToWiFi: false)
                }
            }
            
        } catch {
            print("❌ Failed to load location details async: \(error.localizedDescription)")
            // Don't show error immediately - user already sees content
        }
    }
    
    private func loadComments() {
        isLoadingComments = true
        commentOffset = 0
        
        dataManager.apiService.getLocationComments(locationId: location.id, limit: 20, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoadingComments = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load comments: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ Comments loaded: \(response.comments.count) items")
                    comments = response.comments
                    hasMoreComments = response.pagination.hasMore
                    commentOffset = response.comments.count
                    
                    // TODO: Load user's liked comments from backend
                    // For now, we'll clear the liked state when reloading
                    // In a real implementation, you would check which comments the user has liked
                    print("🔄 Comments reloaded - clearing temporary like states")
                    // likedComments.removeAll() // Commented out to maintain likes during session
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadMoreComments() {
        guard !isLoadingComments && hasMoreComments else { return }
        
        isLoadingComments = true
        
        dataManager.apiService.getLocationComments(locationId: location.id, limit: 20, offset: commentOffset)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoadingComments = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load more comments: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ More comments loaded: \(response.comments.count) items")
                    comments.append(contentsOf: response.comments)
                    hasMoreComments = response.pagination.hasMore
                    commentOffset += response.comments.count
                }
            )
            .store(in: &cancellables)
    }
    
    private func sendMessage() {
        let message = chatMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty && !isPostingComment else { return }
        
        isPostingComment = true
        
        // Handle reply vs new comment
        let apiCall: AnyPublisher<AddCommentResponse, APIError>
        if let parentComment = replyingToComment {
            apiCall = dataManager.apiService.addComment(locationId: location.id, commentText: message, parentCommentId: parentComment.id)
        } else {
            apiCall = dataManager.apiService.addComment(locationId: location.id, commentText: message)
        }
        
        apiCall
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isPostingComment = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to post comment: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ Comment posted successfully")
                    chatMessage = ""
                    let wasReply = replyingToComment != nil
                    let parentId = replyingToComment?.id
                    replyingToComment = nil
                    
                    if wasReply, let parentCommentId = parentId {
                        // This was a reply - refresh comments to get proper reply structure
                        print("🔄 Reply posted - refreshing comments to show proper structure")
                        loadComments()
                        // Show replies for the parent comment
                        showingReplies.insert(parentCommentId)
                    } else {
                        // This was a new top-level comment
                        comments.insert(response.comment, at: 0)
                    }
                    // Update comment count in location details
                    if var details = locationDetails {
                        details = LocationDetails(
                            id: details.id,
                            title: details.title,
                            description: details.description,
                            latitude: details.latitude,
                            longitude: details.longitude,
                            address: details.address,
                            viewsCount: details.viewsCount,
                            likesCount: details.likesCount,
                            bookmarksCount: details.bookmarksCount,
                            commentsCount: details.commentsCount + 1,
                            submissionDate: details.submissionDate,
                            featured: details.featured,
                            categoryName: details.categoryName,
                            categoryIcon: details.categoryIcon,
                            categoryColor: details.categoryColor,
                            dangerLevel: details.dangerLevel,
                            dangerColor: details.dangerColor,
                            dangerDescription: details.dangerDescription,
                            riskLevel: details.riskLevel,
                            submittedByUsername: details.submittedByUsername,
                            submittedByAvatar: details.submittedByAvatar,
                            images: details.images,
                            videos: details.videos,
                            tags: details.tags,
                            timeline: details.timeline,
                            userInteractions: details.userInteractions
                        )
                        locationDetails = details
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func trackViewIfNeeded() {
        // Track the view only once per location across the entire app session
        guard !hasTrackedView && !Self.trackedLocationIds.contains(location.id) else { 
            print("👁️ Skipping view tracking for location \(location.id) - already tracked this session")
            return 
        }
        hasTrackedView = true
        Self.trackedLocationIds.insert(location.id)
        print("👁️ Tracking view for location \(location.id) - first time this session")
        
        dataManager.apiService.trackLocationVisit(locationId: location.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to track view: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ View tracked successfully. New count: \(response.viewCount)")
                    // Update view count in location details
                    if var details = locationDetails {
                        details = LocationDetails(
                            id: details.id,
                            title: details.title,
                            description: details.description,
                            latitude: details.latitude,
                            longitude: details.longitude,
                            address: details.address,
                            viewsCount: response.viewCount,
                            likesCount: details.likesCount,
                            bookmarksCount: details.bookmarksCount,
                            commentsCount: details.commentsCount,
                            submissionDate: details.submissionDate,
                            featured: details.featured,
                            categoryName: details.categoryName,
                            categoryIcon: details.categoryIcon,
                            categoryColor: details.categoryColor,
                            dangerLevel: details.dangerLevel,
                            dangerColor: details.dangerColor,
                            dangerDescription: details.dangerDescription,
                            riskLevel: details.riskLevel,
                            submittedByUsername: details.submittedByUsername,
                            submittedByAvatar: details.submittedByAvatar,
                            images: details.images,
                            videos: details.videos,
                            tags: details.tags,
                            timeline: details.timeline,
                            userInteractions: UserInteractions(
                                isLiked: details.userInteractions.isLiked,
                                isBookmarked: details.userInteractions.isBookmarked,
                                hasVisited: true
                            )
                        )
                        locationDetails = details
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func toggleLike() {
        guard var details = locationDetails else { return }
        
        dataManager.apiService.toggleLike(locationId: location.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to toggle like: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ Like toggled: \(response.isLiked)")
                    print("💗 Updating UI: isLiked=\(response.isLiked), was=\(details.userInteractions.isLiked)")
                    // Update the UI immediately
                    let newLikeCount = response.isLiked ? details.likesCount + 1 : max(0, details.likesCount - 1)
                    let newUserInteractions = UserInteractions(
                        isLiked: response.isLiked,
                        isBookmarked: details.userInteractions.isBookmarked,
                        hasVisited: details.userInteractions.hasVisited
                    )
                    
                    details = LocationDetails(
                        id: details.id,
                        title: details.title,
                        description: details.description,
                        latitude: details.latitude,
                        longitude: details.longitude,
                        address: details.address,
                        viewsCount: details.viewsCount,
                        likesCount: newLikeCount,
                        bookmarksCount: details.bookmarksCount,
                        commentsCount: details.commentsCount,
                        submissionDate: details.submissionDate,
                        featured: details.featured,
                        categoryName: details.categoryName,
                        categoryIcon: details.categoryIcon,
                        categoryColor: details.categoryColor,
                        dangerLevel: details.dangerLevel,
                        dangerColor: details.dangerColor,
                        dangerDescription: details.dangerDescription,
                        riskLevel: details.riskLevel,
                        submittedByUsername: details.submittedByUsername,
                        submittedByAvatar: details.submittedByAvatar,
                        images: details.images,
                        videos: details.videos,
                        tags: details.tags,
                        timeline: details.timeline,
                        userInteractions: newUserInteractions
                    )
                    locationDetails = details
                }
            )
            .store(in: &cancellables)
    }
    
    private func toggleBookmark() {
        guard var details = locationDetails else { return }
        
        dataManager.apiService.toggleBookmark(locationId: location.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to toggle bookmark: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ Bookmark toggled: \(response.isBookmarked)")
                    print("🔖 Updating UI: isBookmarked=\(response.isBookmarked), was=\(details.userInteractions.isBookmarked)")
                    // Update the UI immediately
                    let newBookmarkCount = response.isBookmarked ? details.bookmarksCount + 1 : max(0, details.bookmarksCount - 1)
                    let newUserInteractions = UserInteractions(
                        isLiked: details.userInteractions.isLiked,
                        isBookmarked: response.isBookmarked,
                        hasVisited: details.userInteractions.hasVisited
                    )
                    
                    details = LocationDetails(
                        id: details.id,
                        title: details.title,
                        description: details.description,
                        latitude: details.latitude,
                        longitude: details.longitude,
                        address: details.address,
                        viewsCount: details.viewsCount,
                        likesCount: details.likesCount,
                        bookmarksCount: newBookmarkCount,
                        commentsCount: details.commentsCount,
                        submissionDate: details.submissionDate,
                        featured: details.featured,
                        categoryName: details.categoryName,
                        categoryIcon: details.categoryIcon,
                        categoryColor: details.categoryColor,
                        dangerLevel: details.dangerLevel,
                        dangerColor: details.dangerColor,
                        dangerDescription: details.dangerDescription,
                        riskLevel: details.riskLevel,
                        submittedByUsername: details.submittedByUsername,
                        submittedByAvatar: details.submittedByAvatar,
                        images: details.images,
                        videos: details.videos,
                        tags: details.tags,
                        timeline: details.timeline,
                        userInteractions: newUserInteractions
                    )
                    locationDetails = details
                }
            )
            .store(in: &cancellables)
    }
    
    private func toggleCommentLike(_ commentId: Int) {
        let wasLiked = likedComments.contains(commentId)
        
        // Optimistic UI update for both local and global state
        if wasLiked {
            likedComments.remove(commentId)
            Self.globalLikedComments.remove(commentId)
        } else {
            likedComments.insert(commentId)
            Self.globalLikedComments.insert(commentId)
        }
        
        // TODO: Replace with actual API call when comment like endpoint is available
        // For now, we'll simulate the API call and update the comment's like count
        print("💖 Toggled like for comment \(commentId): \(wasLiked ? "unliked" : "liked")")
        
        // Update the comment's like count in the local array
        if let commentIndex = comments.firstIndex(where: { $0.id == commentId }) {
            var updatedComment = comments[commentIndex]
            // Create a new comment with updated like count (since Comment properties are let)
            // This is a temporary solution until we have proper API integration
            print("📊 Updated like count for comment \(commentId)")
        }
        
        // In a real implementation, you would call:
        // dataManager.apiService.toggleCommentLike(commentId: commentId)
        //     .receive(on: DispatchQueue.main)
        //     .sink(receiveCompletion: { ... }, receiveValue: { response in
        //         // Update UI with server response
        //     })
        //     .store(in: &cancellables)
    }
    
    private func toggleReplies(for commentId: Int) {
        if showingReplies.contains(commentId) {
            showingReplies.remove(commentId)
        } else {
            showingReplies.insert(commentId)
        }
    }
    
    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000.0)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        } else {
            return "\(number)"
        }
    }
    
    private func categoryIconName(for category: String) -> String {
        switch category.lowercased() {
        case "hospital": return "cross.fill"
        case "church": return "building.columns.fill"
        case "factory": return "building.2.fill"
        case "house": return "house.fill"
        case "school": return "graduationcap.fill"
        case "theater": return "theatermasks.fill"
        case "mall": return "storefront.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    private func loadNearbyLocations() {
        guard !isLoadingNearby else { return }
        isLoadingNearby = true
        
        // Use the existing nearby locations API
        dataManager.apiService.getNearbyLocations(
            latitude: location.latitude,
            longitude: location.longitude,
            radius: 50 // 50km radius
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoadingNearby = false
                if case .failure(let error) = completion {
                    print("❌ Failed to load nearby locations: \(error.localizedDescription)")
                }
            },
            receiveValue: { response in
                // Filter out the current location
                nearbyLocations = response.locations.filter { $0.id != location.id }
                print("✅ Loaded \(nearbyLocations.count) nearby locations")
            }
        )
        .store(in: &cancellables)
    }
    
    private func dangerLevelColor(_ colorString: String?) -> Color {
        switch colorString?.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        default: return .gray
        }
    }
    
    private func formatRelativeTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct TimelineEventView: View {
    let event: TimelineEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot
            Circle()
                .fill(event.eventType == "submission" ? Color.orange : Color.gray)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formatRelativeTime(event.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(event.description)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
    }
    
    private func formatRelativeTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SimpleChatMessageView: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            if let avatarUrl = comment.avatar {
                CachedAsyncImage(url: avatarUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 28))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.username)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Text(formatRelativeTime(comment.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                
                Text(comment.commentText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private func formatRelativeTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ChatMessageView: View {
    let comment: Comment
    
    var body: some View {
        SimpleChatMessageView(comment: comment)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var currentX: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentX + subviewSize.width > width && currentX > 0 {
                height += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
            }
            
            currentX += subviewSize.width + spacing
            currentRowHeight = max(currentRowHeight, subviewSize.height)
        }
        
        height += currentRowHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentX + subviewSize.width > bounds.maxX && currentX > bounds.minX {
                currentY += currentRowHeight + spacing
                currentX = bounds.minX
                currentRowHeight = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(subviewSize))
            currentX += subviewSize.width + spacing
            currentRowHeight = max(currentRowHeight, subviewSize.height)
        }
    }
}

// MARK: - Modern Component Views

struct ModernInteractionCard: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isActive ? color : .white.opacity(0.8))
                
                Text("\(formatCount(count))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isActive ? AnyShapeStyle(color.opacity(0.15)) : AnyShapeStyle(Material.ultraThinMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? color.opacity(0.3) : .white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
}

struct StatCard: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    var isInteractive: Bool = false
    var isViewsCard: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, isViewsCard ? 16 : 12)
        .padding(.vertical, 10)
        .background(isInteractive ? Material.ultraThinMaterial.opacity(0.8) : Material.ultraThinMaterial.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(subtitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Material.ultraThinMaterial.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ModernTimelineEvent: View {
    let event: TimelineEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack {
                Circle()
                    .fill(.orange)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(formatRelativeTime(event.timestamp))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                
                Text(event.description)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineLimit(nil)
                
                if let username = event.username {
                    Text("by \(username)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Material.ultraThinMaterial.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private func formatRelativeTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

struct NearbyLocationCard: View {
    let location: AbandonedLocation
    let currentLocation: AbandonedLocation
    
    private var distance: String {
        let location1 = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let location2 = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let distanceInMeters = location1.distance(from: location2)
        let distanceInKm = distanceInMeters / 1000
        
        if distanceInKm < 1 {
            return String(format: "%.0fm", distanceInMeters)
        } else {
            return String(format: "%.1fkm", distanceInKm)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Real image or placeholder
            if let firstImageUrl = location.displayImages.first {
                CachedAsyncImage(url: firstImageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text(distance)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.black.opacity(0.7))
                                        .clipShape(Capsule())
                                }
                                .padding(8)
                            }
                        )
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Material.ultraThinMaterial.opacity(0.6))
                        .frame(width: 160, height: 120)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Material.ultraThinMaterial.opacity(0.6))
                    .frame(width: 160, height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(distance)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if !location.categoryName.isEmpty {
                    Text(location.categoryName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .frame(width: 160)
        .padding(12)
        .background(Material.ultraThinMaterial.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct AdvancedCommentView: View {
    let comment: Comment
    let isLiked: Bool
    let showReplies: Bool
    let onLike: () -> Void
    let onReply: () -> Void
    let onToggleReplies: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                Circle()
                    .fill(Material.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(comment.username.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack {
                        Text(comment.username)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text(formatRelativeTime(comment.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                    }
                    
                    // Comment text
                    Text(comment.commentText)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineLimit(nil)
                    
                    // Action buttons (TikTok style)
                    HStack(spacing: 20) {
                        // Like button
                        Button(action: onLike) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(isLiked ? .red : .white.opacity(0.7))
                                
                                Text("\(comment.likesCount + (isLiked ? 1 : 0))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Reply button
                        Button(action: onReply) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("Reply")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Show replies button
                        let actualReplyCount = comment.replies?.count ?? comment.replyCount ?? 0
                        if actualReplyCount > 0 {
                            Button(action: onToggleReplies) {
                                HStack(spacing: 4) {
                                    Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Text("\(actualReplyCount) \(actualReplyCount == 1 ? "reply" : "replies")")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            
            // Replies (if showing)
            if showReplies, let replies = comment.replies, !replies.isEmpty {
                VStack(spacing: 8) {
                    ForEach(replies) { reply in
                        HStack(alignment: .top, spacing: 8) {
                            // Reply line
                            Rectangle()
                                .fill(.white.opacity(0.3))
                                .frame(width: 2, height: 30)
                                .padding(.leading, 18)
                            
                            // Small avatar for replies
                            Circle()
                                .fill(Material.ultraThinMaterial)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(String(reply.username.prefix(1)).uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            // Reply content
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(reply.username)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.orange)
                                    
                                    Text(formatRelativeTime(reply.createdAt))
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Spacer()
                                }
                                
                                Text(reply.commentText)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                    .lineLimit(nil)
                            }
                            
                            Spacer()
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Material.ultraThinMaterial.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
    
    private func formatRelativeTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MediaItemView: View {
    let mediaItem: MediaItem
    
    var body: some View {
        if mediaItem.isVideo {
            // Video player view
            if let videoURL = URL(string: mediaItem.url) {
                VideoPlayerView(url: videoURL)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.system(size: 30))
                            Text("Invalid video URL")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    )
            }
        } else {
            // Image view
            CachedAsyncImage(url: mediaItem.url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
    }
}

#Preview {
    LocationDetailModalView(
        location: AbandonedLocation(
            id: 1,
            title: "Abandoned Hospital",
            description: "Old psychiatric facility with creepy atmosphere",
            latitude: 42.3436,
            longitude: 27.1904,
            address: "Sredets, Bulgaria",
            tags: ["creepy", "hospital", "abandoned"],
            images: [],
            categoryName: "Hospital",
            dangerLevel: "Caution"
        ),
        selectedLocation: .constant(nil)
    )
    .environmentObject(DataManager())
    .environmentObject(LocationManager())
} 