//
//  LocationGlobal.swift
//  GeoDrive
//
//  Created by Glenn Posadas on 3/16/17.
//  Copyright © 2017 Glenn Posadas. All rights reserved.
//

import CoreLocation
import UIKit

class LocationGlobal {
    
    /** Singleton for storing and accessing global data and functions
     */
    
    class var shared: LocationGlobal {
        struct Static {
            static let instance = LocationGlobal()
        }
        
        return Static.instance
    }
    
    // MARK: - Singleton Properties
    
    var timer : Timer?
    var bgTask : BackgroundTaskManager?
    var myLocationArray : NSMutableArray?
}
