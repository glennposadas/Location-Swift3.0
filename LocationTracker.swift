//
//  LocationTracker.swift
//  Location
//
//  Created by Glenn Posadas on 4/19/17.
//  Copyright © 2017 Glenn Posadas. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

let LATITUDE = "latitude"
let LONGITUDE = "longitude"
let ACCURACY = "theAccuracy"

protocol LocationTrackerDelegate: NSObjectProtocol {
    func locationTracker(shouldPresentMessage message: String, locationTracker: LocationTracker)
    func locationTracker(newLog log: String, locationTracker: LocationTracker)
}

class LocationTracker : NSObject, CLLocationManagerDelegate, UIAlertViewDelegate {
    
    var myLastLocation : CLLocationCoordinate2D?
    var myLastLocationAccuracy : CLLocationAccuracy?
    
    var accountStatus: NSString?
    var authKey: NSString?
    var device: NSString?
    var name: NSString?
    var profilePicURL: NSString?
    var userid: Int?
    
    var locationGlobal: LocationGlobal?
    
    var myLocation : CLLocationCoordinate2D?
    var myLocationAcuracy : CLLocationAccuracy?
    var myLocationAltitude : CLLocationDistance?
    
    weak var delegate: LocationTrackerDelegate?
    
    override init()  {
        super.init()
        self.locationGlobal = LocationGlobal()
        self.locationGlobal!.myLocationArray = NSMutableArray()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationEnterBackground),
            name: NSNotification.Name.UIApplicationDidEnterBackground,
            object: nil
        )
        
    }
    
    class func shared()->CLLocationManager? {
        
        struct Static {
            static var _locationManager : CLLocationManager?
        }
        
        objc_sync_enter(self)
        if Static._locationManager == nil {
            Static._locationManager = CLLocationManager()
            Static._locationManager!.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            Static._locationManager!.allowsBackgroundLocationUpdates = true
            Static._locationManager!.pausesLocationUpdatesAutomatically = false
            Static._locationManager!.distanceFilter = 99999
        }
        
        objc_sync_exit(self)
        return Static._locationManager!
    }
    
    // MARK: Application in background
    func applicationEnterBackground() {
        self.startUpdatingLocationByAccuracy()
        
        self.locationGlobal!.bgTask = BackgroundTaskManager.shared()
        _ = self.locationGlobal?.bgTask?.beginNewBackgroundTask()
    }
    
    func restartLocationUpdates() {
        
        self.delegate?.locationTracker(newLog: "restartLocationUpdates\n", locationTracker: self)
        
        if self.locationGlobal?.timer != nil {
            self.locationGlobal?.timer?.invalidate()
            self.locationGlobal!.timer = nil
        }
        
        self.startUpdatingLocationByAccuracy()
    }
    
    func startLocationTracking() {
        
        self.delegate?.locationTracker(newLog: "startLocationTracking\n", locationTracker: self)
        
        if CLLocationManager.locationServicesEnabled() == false {
            self.delegate?.locationTracker(shouldPresentMessage: "locationServicesEnabled false\n", locationTracker: self)
        } else {
            let authorizationStatus: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
            
            if (authorizationStatus == .denied) || (authorizationStatus == .restricted) {
                self.delegate?.locationTracker(shouldPresentMessage: "authorizationStatus failed\n", locationTracker: self)
            } else {
                self.startUpdatingLocationByAccuracy()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        self.delegate?.locationTracker(newLog: "locationManager didUpdateLocations\n", locationTracker: self)
        
        for newLocation in locations {
            let theLocation = newLocation.coordinate
            let theAltitude = newLocation.altitude
            let theAccuracy = newLocation.horizontalAccuracy
            let locationAge = newLocation.timestamp.timeIntervalSinceNow
            
            if locationAge > 30.0 {
                continue
            }
            
            // Select only valid location and also location with good accuracy
            if (theAccuracy > 0) && (theAccuracy < 2000) && !((theLocation.latitude == 0.0) && (theLocation.longitude == 0.0)) {
                self.myLastLocation = theLocation
                self.myLastLocationAccuracy = theAccuracy
                
                let dict = NSMutableDictionary()
                dict.setObject(NSNumber(value: theLocation.latitude), forKey: "latitude" as NSCopying)
                dict.setObject(NSNumber(value: theLocation.longitude), forKey: "longitude" as NSCopying)
                dict.setObject(NSNumber(value: theAccuracy), forKey: "theAccuracy" as NSCopying)
                dict.setObject(NSNumber(value: theAltitude), forKey: "theAltitude" as NSCopying)
                
                // Add the valid location with good accuracy into an array
                // Every 1 minute, I will select the best location based on accuracy and send to server
                self.locationGlobal!.myLocationArray!.add(dict)
            }
        }
        
        // If the timer still valid, return it (Will not run the code below)
        if self.locationGlobal!.timer != nil {
            return
        }
        
        self.locationGlobal!.bgTask = BackgroundTaskManager.shared()
        _ = self.locationGlobal!.bgTask!.beginNewBackgroundTask()
        
        // Restart the locationManager after 1 minute
        self.locationGlobal?.timer = Timer.scheduledTimer(
            timeInterval: 60,
            target: self,
            selector: #selector(restartLocationUpdates),
            userInfo: nil,
            repeats: false
        )
        
        // Will only stop the locationManager after 7 seconds, so that we can get some accurate locations
        // The location manager will only operate for 7 seconds to save battery
        Timer.scheduledTimer(
            timeInterval: 7,
            target: self,
            selector: #selector(stopLocationDelayBy7Seconds),
            userInfo: nil,
            repeats: false
        )
    }
    
    //MARK: Stop the locationManager
    func stopLocationDelayBy7Seconds() {
        self.stopUpdatingLocationByAccuracy()
        self.delegate?.locationTracker(newLog: "locationManager stop Updating after 7 seconds\n", locationTracker: self)
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        switch (nsError.code) {
        case CLError.network.rawValue, CLError.denied.rawValue:
            self.delegate?.locationTracker(newLog: "Please check your network connection", locationTracker: self)
        default: break
        }
    }
    
    func stopLocationTracking() {
        
        self.delegate?.locationTracker(newLog: "stopLocationTracking\n", locationTracker: self)
        
        if self.locationGlobal!.timer != nil {
            self.locationGlobal!.timer!.invalidate()
            self.locationGlobal!.timer = nil
        }
        
        self.stopUpdatingLocationByAccuracy()
    }
    
    // MARK: Update location to server
    
    func updateLocationToServer() {
        
        self.delegate?.locationTracker(newLog: "updateLocationToServer\n", locationTracker: self)
        
        // Find the best location from the array based on accuracy
        var myBestLocation = NSMutableDictionary()
        
        if let myLocationArray = self.locationGlobal?.myLocationArray {
            for (index, myLocation) in myLocationArray.enumerated() {
                if let currentLocation = myLocation as? NSMutableDictionary {
                    if index == 0 {
                        myBestLocation = currentLocation
                    } else {
                        if let currentLocationAccuracy = currentLocation.object(forKey: ACCURACY) as? Float,
                            let myBestLocationAccuracy = myBestLocation.object(forKey: ACCURACY) as? Float {
                            if currentLocationAccuracy <= myBestLocationAccuracy {
                                myBestLocation = currentLocation
                            }
                        }
                    }
                }
            }
        }
        
        self.delegate?.locationTracker(newLog: "My Best location \(myBestLocation)\n", locationTracker: self)
        
        // If the array is 0, get the last location
        // Sometimes due to network issue or unknown reason,
        // you could not get the location during that period, the best you can do is
        // sending the last known location to the server
        
        if self.locationGlobal!.myLocationArray!.count == 0 {
            
            self.delegate?.locationTracker(newLog: "Unable to get location, use the last known location \n", locationTracker: self)
            
            self.myLocation = self.myLastLocation
            self.myLocationAcuracy = self.myLastLocationAccuracy
        } else {
            if let lat = myBestLocation.object(forKey: LATITUDE) as? CLLocationDegrees,
                let long = myBestLocation.object(forKey: LONGITUDE) as? CLLocationDegrees,
                let bestLocationAccuracy = myBestLocation.object(forKey: ACCURACY) as? CLLocationAccuracy {
                self.myLocation = CLLocationCoordinate2D(latitude: lat, longitude: long)
                self.myLocationAcuracy = bestLocationAccuracy
            }
        }
        
        self.delegate?.locationTracker(newLog: "Should send to server: latitude \(String(describing: self.myLocation?.latitude)) longitude \(String(describing: self.myLocation?.longitude)) accuracy \(String(describing: self.myLocationAcuracy))\n", locationTracker: self)
        
        //TODO: Your code to send the self.myLocation and self.myLocationAccuracy to your server
        
        
        // After sending the location to the server successful,
        // remember to clear the current array with the following code. It is to make sure that you clear up old location in the array
        // and add the new locations from locationManager
        
        self.locationGlobal!.myLocationArray!.removeAllObjects()
        self.locationGlobal!.myLocationArray = nil
        self.locationGlobal!.myLocationArray = NSMutableArray()
    }
    
}

// MARK: - New toggle Location state by Accuracy Extension

extension LocationTracker {
    func startUpdatingLocationByAccuracy() {
        let locationManager = LocationTracker.shared()!
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = 99999
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocationByAccuracy() {
        let locationManager = LocationTracker.shared()!
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.stopUpdatingLocation()
    }
}
