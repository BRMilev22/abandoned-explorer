//
//  LocationManager.swift
//  upwork-project
//
//  Created by Boris Milev on 22.06.25.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        print("🔄 LocationManager initialized with status: \(authorizationStatus.rawValue)")
        checkLocationAuthorization()
    }
    
    func requestLocationPermission() {
        print("Requesting location permission...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    func checkLocationAuthorization() {
        print("🔍 Checking location authorization. Current status: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .notDetermined:
            print("🔒 Location not determined, requesting permission...")
            requestLocationPermission()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable location services in Settings."
            print("❌ Location access denied or restricted")
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location authorized, starting updates...")
            startLocationUpdates()
        @unknown default:
            print("⚠️ Unknown authorization status")
            break
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Cannot start location updates: insufficient permissions")
            return
        }
        
        print("Starting location updates...")
        locationManager.startUpdatingLocation()
        
        // Also request a one-time location update
        locationManager.requestLocation()
    }
    
    func stopLocationUpdates() {
        print("Stopping location updates...")
        locationManager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { 
            print("⚠️ No location in update")
            return 
        }
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
        
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil
            print("✅ User location set: \(location.coordinate)")
        }
        
        // Stop continuous updates after getting the first location
        locationManager.stopUpdatingLocation()
        print("⏹️ Stopped location updates")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.locationError = "Failed to get location: \(error.localizedDescription)"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔄 Authorization status changed to: \(status.rawValue)")
        DispatchQueue.main.async {
            self.authorizationStatus = status
            print("📱 Updated authorization status on main thread: \(status.rawValue)")
            self.checkLocationAuthorization()
        }
    }
}
