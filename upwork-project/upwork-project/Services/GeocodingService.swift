//
//  GeocodingService.swift
//  upwork-project
//
//  Created by Boris Milev on 24.06.25.
//

import Foundation
import CoreLocation
import Combine

class GeocodingService: ObservableObject {
    private let geocoder = CLGeocoder()
    private var lastGeocodeTime = Date.distantPast
    private let geocodeThrottle: TimeInterval = 2.0 // Limit geocoding to once every 2 seconds
    
    @Published var currentLocationName: String = "Locating..."
    @Published var currentCountry: String?
    @Published var currentState: String?
    @Published var currentCity: String?
    @Published var isEurope: Bool = false
    @Published var isUSA: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D, zoomLevel: Double) {
        // Throttle geocoding requests to avoid overwhelming the service
        let now = Date()
        guard now.timeIntervalSince(lastGeocodeTime) >= geocodeThrottle else {
            return
        }
        lastGeocodeTime = now
        
        // Cancel any existing geocoding requests
        geocoder.cancelGeocode()
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    self?.setFallbackLocation(coordinate: coordinate, zoomLevel: zoomLevel)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    self?.setFallbackLocation(coordinate: coordinate, zoomLevel: zoomLevel)
                    return
                }
                
                self?.processPlacemark(placemark, zoomLevel: zoomLevel)
            }
        }
    }
    
    func forceInitialGeocode(coordinate: CLLocationCoordinate2D, zoomLevel: Double) {
        print("🚀 Force initial geocode for: \(coordinate)")
        // Cancel any existing geocoding requests
        geocoder.cancelGeocode()
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorCode = (error as NSError).code
                    print("Initial geocoding error: \(error.localizedDescription) (Code: \(errorCode))")
                    
                    // Handle specific error codes
                    if errorCode == 10 { // kCLErrorGeocodeFoundNoResult
                        print("No geocoding result found, using fallback")
                    } else if errorCode == 2 { // kCLErrorNetwork
                        print("Network error during geocoding, using fallback")
                    }
                    
                    self?.setFallbackLocation(coordinate: coordinate, zoomLevel: zoomLevel)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("No placemark found for initial geocoding")
                    self?.setFallbackLocation(coordinate: coordinate, zoomLevel: zoomLevel)
                    return
                }
                
                print("✅ Initial geocoding successful")
                self?.processPlacemark(placemark, zoomLevel: zoomLevel)
            }
        }
    }
    
    private func processPlacemark(_ placemark: CLPlacemark, zoomLevel: Double) {
        let country = placemark.country ?? "Unknown"
        let state = placemark.administrativeArea
        let city = placemark.locality ?? placemark.subAdministrativeArea
        
        currentCountry = country
        currentState = state
        currentCity = city
        
        // Determine if location is in Europe or USA
        isUSA = country == "United States" || placemark.isoCountryCode == "US"
        isEurope = isEuropeanCountry(countryCode: placemark.isoCountryCode)
        
        // Generate location name based on zoom level and region
        currentLocationName = generateLocationName(
            country: country,
            state: state,
            city: city,
            zoomLevel: zoomLevel
        )
    }
    
    private func isEuropeanCountry(countryCode: String?) -> Bool {
        guard let code = countryCode else { return false }
        
        let europeanCountries = [
            "AD", "AL", "AT", "BA", "BE", "BG", "BY", "CH", "CY", "CZ",
            "DE", "DK", "EE", "ES", "FI", "FR", "GB", "GE", "GR", "HR",
            "HU", "IE", "IS", "IT", "LI", "LT", "LU", "LV", "MC", "MD",
            "ME", "MK", "MT", "NL", "NO", "PL", "PT", "RO", "RS", "RU",
            "SE", "SI", "SK", "SM", "UA", "VA"
        ]
        
        return europeanCountries.contains(code)
    }
    
    private func generateLocationName(country: String, state: String?, city: String?, zoomLevel: Double) -> String {
        if zoomLevel < 6.0 {
            return "Worldwide"
        } else if zoomLevel < 8.0 {
            // Continental level
            if isEurope {
                return "Europe"
            } else if isUSA {
                return "United States"
            } else {
                return country
            }
        } else if zoomLevel < 10.0 {
            // Country level
            return country
        } else if zoomLevel < 12.0 {
            // State/Region level
            if isUSA, let state = state {
                return state
            } else if isEurope {
                return country
            } else {
                return state ?? country
            }
        } else {
            // City level
            if isUSA {
                if let city = city, let state = state {
                    return "\(city), \(getStateAbbreviation(state))"
                } else if let state = state {
                    return state
                } else {
                    return "Local Area"
                }
            } else if isEurope {
                if let city = city {
                    return "\(city), \(country)"
                } else {
                    return country
                }
            } else {
                return city ?? "Local Area"
            }
        }
    }
    
    private func getStateAbbreviation(_ stateName: String) -> String {
        let stateAbbreviations = [
            "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
            "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
            "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
            "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
            "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
            "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
            "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
            "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
            "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
            "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
            "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
            "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
            "Wisconsin": "WI", "Wyoming": "WY"
        ]
        
        return stateAbbreviations[stateName] ?? stateName
    }
    
    private func setFallbackLocation(coordinate: CLLocationCoordinate2D, zoomLevel: Double) {
        // Fallback to coordinate-based location detection
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        
        print("🔄 Using fallback location detection for: \(lat), \(lng)")
        
        // Don't use fallback for invalid or default coordinates (like US center)
        if abs(lat - 39.8283) < 0.1 && abs(lng - (-98.5795)) < 0.1 {
            print("🚫 Skipping fallback for default US center coordinate")
            return
        }
        
        if zoomLevel < 6.0 {
            currentLocationName = "Worldwide"
        } else if zoomLevel < 8.0 {
            // Rough continental detection
            if lat >= 35.0 && lat <= 72.0 && lng >= -25.0 && lng <= 45.0 {
                currentLocationName = "Europe"
                isEurope = true
                isUSA = false
            } else if lat >= 25.0 && lat <= 49.0 && lng >= -125.0 && lng <= -66.0 {
                currentLocationName = "United States"
                isUSA = true
                isEurope = false
            } else {
                currentLocationName = "International"
                isUSA = false
                isEurope = false
            }
        } else if zoomLevel < 10.0 {
            // Country level fallback
            if lat >= 25.0 && lat <= 49.0 && lng >= -125.0 && lng <= -66.0 {
                currentLocationName = "United States"
                isUSA = true
                isEurope = false
            } else if lat >= 35.0 && lat <= 72.0 && lng >= -25.0 && lng <= 45.0 {
                currentLocationName = "Europe"
                isEurope = true
                isUSA = false
            } else {
                currentLocationName = "International"
                isUSA = false
                isEurope = false
            }
        } else {
            // More specific fallback based on known coordinate ranges
            // US cities
            if lat >= 40.6 && lat <= 40.9 && lng >= -74.1 && lng <= -73.8 {
                currentLocationName = "New York, NY"
                isUSA = true
                isEurope = false
            } else if lat >= 34.0 && lat <= 34.3 && lng >= -118.5 && lng <= -118.2 {
                currentLocationName = "Los Angeles, CA"
                isUSA = true
                isEurope = false
            } else if lat >= 32.6 && lat <= 32.9 && lng >= -97.0 && lng <= -96.6 {
                currentLocationName = "Dallas, TX"
                isUSA = true
                isEurope = false
            }
            // European cities/countries
            else if lat >= 42.0 && lat <= 43.5 && lng >= 26.0 && lng <= 28.5 {
                currentLocationName = "Bulgaria"
                isEurope = true
                isUSA = false
            } else if lat >= 50.0 && lat <= 55.0 && lng >= 2.0 && lng <= 7.0 {
                currentLocationName = "Netherlands"
                isEurope = true
                isUSA = false
            } else if lat >= 48.0 && lat <= 51.0 && lng >= 2.0 && lng <= 8.0 {
                currentLocationName = "France"
                isEurope = true
                isUSA = false
            } else if lat >= 51.0 && lat <= 56.0 && lng >= -8.0 && lng <= 2.0 {
                currentLocationName = "United Kingdom"
                isEurope = true
                isUSA = false
            } else if lat >= 47.0 && lat <= 55.0 && lng >= 5.0 && lng <= 15.0 {
                currentLocationName = "Germany"
                isEurope = true
                isUSA = false
            }
            // Broader regional fallbacks
            else if lat >= 25.0 && lat <= 49.0 && lng >= -125.0 && lng <= -66.0 {
                currentLocationName = "United States"
                isUSA = true
                isEurope = false
            } else if lat >= 35.0 && lat <= 72.0 && lng >= -25.0 && lng <= 45.0 {
                currentLocationName = "Europe"
                isEurope = true
                isUSA = false
            } else {
                currentLocationName = "Unknown Location"
                isUSA = false
                isEurope = false
            }
        }
        
        print("📍 Fallback location set to: \(currentLocationName)")
    }
    
    func getHeaderLocationText(zoomLevel: Double) -> String {
        // Return the same context that matches the active users context
        return getActiveUsersContextName(zoomLevel: zoomLevel).lowercased()
    }
    
    func resetLocationToLocating() {
        DispatchQueue.main.async {
            self.currentLocationName = "Locating..."
            self.currentCountry = nil
            self.currentState = nil
            self.currentCity = nil
            self.isEurope = false
            self.isUSA = false
        }
    }
    
    func getActiveUsersContextName(zoomLevel: Double) -> String {
        // Return the same context name that's displayed in the header
        // This ensures header and bottom info are always synchronized
        return generateLocationName(
            country: currentCountry ?? "Unknown",
            state: currentState,
            city: currentCity,
            zoomLevel: zoomLevel
        )
    }
    
    func getActiveUsersRadius(zoomLevel: Double) -> Double {
        // Return appropriate radius for active users query based on zoom level
        // Adjusted for better visibility at city/country levels
        switch zoomLevel {
        case 16.0...: // Street level
            return 1.0
        case 14.0..<16.0: // Neighborhood  
            return 3.0
        case 12.0..<14.0: // City level - should show users across the whole city
            return 25.0
        case 10.0..<12.0: // State/Region level - should show users across the region
            return 100.0
        case 8.0..<10.0: // Country level - should show users across the country
            return 500.0
        case 6.0..<8.0: // Continental level
            return 2000.0
        default: // Worldwide
            return 20000.0 // Global radius
        }
    }
}
