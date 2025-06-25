//
//  APIConfiguration.swift
//  upwork-project
//
//  Created by Boris Milev on 23.06.25.
//

import Foundation

struct APIConfiguration {
    static let shared = APIConfiguration()
    
    private init() {}
    
    #if DEBUG
    let baseURL = "http://192.168.0.116:3000/api"
    #else
    let baseURL = "https://your-production-api.com/api" // Replace with your production URL
    #endif
    
    var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
