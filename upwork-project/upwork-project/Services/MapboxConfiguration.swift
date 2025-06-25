//
//  MapboxConfiguration.swift
//  upwork-project
//
//  Created by Boris Milev on 24.06.25.
//

import Foundation
import MapboxMaps

struct MapboxConfiguration {
    static let accessToken = "pk.eyJ1IjoienZhcmF6b2t1MjAwMCIsImEiOiJjbWM5cDJtOTIwb3UzMnZzOXoxcHhoMXg1In0.8tTe5jjazx0J-5_g6ijbxg"
    static let customStyleURL = "mapbox://styles/zvarazoku2000/cmc9pi2qq039h01sc6drb831k"
    
    static func configure() {
        // Set the default access token for Mapbox
        MapboxOptions.accessToken = accessToken
    }
}
