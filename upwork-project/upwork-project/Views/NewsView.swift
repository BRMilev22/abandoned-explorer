//
//  NewsView.swift
//  upwork-project
//
//  Created by Boris Milev on 24.06.25.
//

import SwiftUI

struct NewsView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "globe.americas")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("News Coming Soon")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Stay tuned for local news and updates about abandoned buildings in your area.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationTitle("News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NewsView()
}
