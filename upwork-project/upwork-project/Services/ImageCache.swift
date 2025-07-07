//
//  ImageCache.swift
//  upwork-project
//
//  Created by Boris Milev on 23.06.25.
//

import SwiftUI
import Combine

class ImageCache: ObservableObject {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    private var loadingImages = Set<String>()
    private var priorityQueue = Set<String>()
    
    private init() {
        // Configure cache limits
        cache.countLimit = 200 // Increased for better performance
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB limit
    }
    
    func cachedImage(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    func setCachedImage(_ image: UIImage, for url: String) {
        // Estimate image size for cache cost
        let cost = Int(image.size.width * image.size.height * 4) // 4 bytes per pixel (RGBA)
        cache.setObject(image, forKey: url as NSString, cost: cost)
    }
    
    func isLoading(_ url: String) -> Bool {
        return loadingImages.contains(url)
    }
    
    func setLoading(_ url: String, isLoading: Bool) {
        if isLoading {
            loadingImages.insert(url)
        } else {
            loadingImages.remove(url)
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        loadingImages.removeAll()
        priorityQueue.removeAll()
    }
    
    // MARK: - Priority Loading for Feed Items
    
    func preloadFeedImages(urls: [String], highPriority: Bool = false) {
        print("🎯 Preloading \(urls.count) feed images (priority: \(highPriority))")
        
        for url in urls {
            guard cachedImage(for: url) == nil, !isLoading(url) else { continue }
            guard let validURL = URL(string: url) else { continue }
            
            if highPriority {
                priorityQueue.insert(url)
            }
            
            setLoading(url, isLoading: true)
            
            // Use high-priority session for visible feed items
            let session = highPriority ? URLSession.shared : URLSession.shared
            
            session.dataTask(with: validURL) { [weak self] data, response, error in
                defer {
                    DispatchQueue.main.async {
                        self?.setLoading(url, isLoading: false)
                        self?.priorityQueue.remove(url)
                    }
                }
                
                if let error = error {
                    print("📱 Feed image preload failed: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data, 
                      let image = UIImage(data: data),
                      data.count < 15_000_000 else { // Increased limit for feed
                    print("📱 Skipping large feed image")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.setCachedImage(image, for: url)
                    print("✅ Cached feed image: \(url)")
                }
            }.resume()
        }
    }
    
    // MARK: - Progressive Loading Support
    
    func loadImageWithProgress(url: String, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        if let cachedImage = cachedImage(for: url) {
            completion(cachedImage)
            return
        }
        
        // Don't start loading if already loading
        guard !isLoading(url) else { return }
        
        guard let validURL = URL(string: url) else {
            completion(nil)
            return
        }
        
        setLoading(url, isLoading: true)
        
        // Create a custom session with optimized settings
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.urlCache = nil // Disable system cache to use our own
        
        let session = URLSession(configuration: config)
        
        session.dataTask(with: validURL) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.setLoading(url, isLoading: false)
                }
            }
            
            if let error = error {
                print("📱 Progressive image load failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                self?.setCachedImage(image, for: url)
                completion(image)
            }
        }.resume()
    }
    
    func preloadImages(urls: [String], limitToWiFi: Bool = false) {
        // More aggressive preloading for better UX
        if limitToWiFi && !isOnWiFi() {
            print("📱 Skipping preload - not on WiFi")
            return
        }
        
        for url in urls {
            guard cachedImage(for: url) == nil, !isLoading(url) else { continue }
            guard let validURL = URL(string: url) else { continue }
            
            setLoading(url, isLoading: true)
            
            URLSession.shared.dataTask(with: validURL) { [weak self] data, response, error in
                defer {
                    DispatchQueue.main.async {
                        self?.setLoading(url, isLoading: false)
                    }
                }
                
                if let error = error {
                    print("📱 Media preload failed (graceful): \(error.localizedDescription)")
                    return
                }
                
                guard let data = data, 
                      let image = UIImage(data: data),
                      data.count < 10_000_000 else {
                    print("📱 Skipping large image for app performance")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.setCachedImage(image, for: url)
                }
            }.resume()
        }
    }
    
    private func isOnWiFi() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false // Be conservative for real devices
        #endif
    }
}

// MARK: - Enhanced CachedAsyncImage with Progressive Loading

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var imageCache = ImageCache.shared
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadingProgress: Double = 0.0
    
    init(
        url: String,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        SwiftUI.Group {
            if let uiImage = loadedImage {
                content(Image(uiImage: uiImage))
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                ZStack {
                    placeholder()
                    
                    // Enhanced loading indicator
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .blur(radius: 10)
                            )
                    }
                }
                .onAppear {
                    loadImageWithProgress()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: loadedImage != nil)
    }
    
    private func loadImageWithProgress() {
        // Check if image is already cached
        if let cachedImage = imageCache.cachedImage(for: url) {
            withAnimation(.easeInOut(duration: 0.3)) {
                loadedImage = cachedImage
            }
            return
        }
        
        // Start loading with progress
        isLoading = true
        imageCache.loadImageWithProgress(url: url) { image in
            withAnimation(.easeInOut(duration: 0.3)) {
                loadedImage = image
                isLoading = false
            }
        }
    }
}

// MARK: - High Priority Feed Image Loader

struct FeedImageLoader: View {
    let url: String
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        SwiftUI.Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        }
                    )
            }
        }
        .onAppear {
            loadImageFast()
        }
    }
    
    private func loadImageFast() {
        // Check cache first
        if let cachedImage = ImageCache.shared.cachedImage(for: url) {
            withAnimation(.easeInOut(duration: 0.2)) {
                image = cachedImage
                isLoading = false
            }
            return
        }
        
        // Load with high priority
        ImageCache.shared.loadImageWithProgress(url: url) { loadedImage in
            withAnimation(.easeInOut(duration: 0.2)) {
                image = loadedImage
                isLoading = false
            }
        }
    }
}

// Convenience initializer similar to AsyncImage
extension CachedAsyncImage where Content == Image, Placeholder == AnyView {
    init(url: String) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { 
                AnyView(
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                )
            }
        )
    }
}
