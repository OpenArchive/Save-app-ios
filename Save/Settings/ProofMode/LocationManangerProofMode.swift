//
//  LocationManangerProofMode.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import CoreLocation
import LibProofMode

class LocationManangerProofMode: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    static let shared = LocationManangerProofMode()
    
    var status: CLAuthorizationStatus {
        LibProofMode.LocationManager.shared.authorizationStatus
    }
    
    private var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    private let observerManager = CLLocationManager()
    
    override private init() {
        super.init()
        observerManager.delegate = self
        observerManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestAuthorization(_ callback: ((_ status: CLAuthorizationStatus) -> Void)? = nil) {
        if status == .notDetermined {
            LibProofMode.LocationManager.shared.getPermission(callback: callback ?? { _ in })
        } else {
            callback?(status)
        }
    }
    
    func monitorAuthorizationChanges(_ callback: @escaping (CLAuthorizationStatus) -> Void) {
        onAuthorizationChange = callback
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        onAuthorizationChange?(status)
    }
}
