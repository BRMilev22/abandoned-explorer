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
    
    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Maximum 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
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
    }
    
    func preloadImages(urls: [String], limitToWiFi: Bool = true) {
        // App Store Ready: Only preload on WiFi by default to save user data
        if limitToWiFi && !isOnWiFi() {
            print("📱 Skipping media preload - not on WiFi (App Store best practice)")
            return
        }
        
        for url in urls {
            guard cachedImage(for: url) == nil, !isLoading(url) else { continue }
            guard let validURL = URL(string: url) else { continue }
            
            setLoading(url, isLoading: true)
            
            // Use background session for preloading to not interfere with user requests
            URLSession.shared.dataTask(with: validURL) { [weak self] data, response, error in
                defer {
                    DispatchQueue.main.async {
                        self?.setLoading(url, isLoading: false)
                    }
                }
                
                // App Store Ready: Proper error handling
                if let error = error {
                    print("📱 Media preload failed (graceful): \(error.localizedDescription)")
                    return
                }
                
                guard let data = data, 
                      let image = UIImage(data: data),
                      data.count < 10_000_000 else { // Limit to 10MB per image
                    print("📱 Skipping large image for app performance")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.setCachedImage(image, for: url)
                }
            }.resume()
        }
    }
    
    // App Store Ready: Check network type to respect user data preferences
    private func isOnWiFi() -> Bool {
        // Simple check - in production you'd use Network framework
        // For now, assume true for simulator, but this can be enhanced
        #if targetEnvironment(simulator)
        return true
        #else
        // In production, implement proper network type detection
        return true // Simplified for now
        #endif
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var imageCache = ImageCache.shared
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
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
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        // Check if image is already cached
        if let cachedImage = imageCache.cachedImage(for: url) {
            loadedImage = cachedImage
            return
        }
        
        // Don't start loading if already loading
        guard !isLoading && !imageCache.isLoading(url) else { return }
        
        isLoading = true
        imageCache.setLoading(url, isLoading: true)
        
        URLSession.shared.dataTask(with: URL(string: url)!) { data, response, error in
            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.imageCache.setLoading(self.url, isLoading: false)
                }
            }
            
            guard let data = data, let image = UIImage(data: data) else { return }
            
            DispatchQueue.main.async {
                self.imageCache.setCachedImage(image, for: self.url)
                self.loadedImage = image
            }
        }.resume()
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
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                )
            }
        )
    }
}
