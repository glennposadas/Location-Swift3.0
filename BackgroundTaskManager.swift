//
//  BackgroundTaskManager.swift
//  Location
//
//  Created by Glenn Posadas on 4/15/17.
//  Copyright © 2017 Glenn Posadas. All rights reserved.
//

import Foundation
import UIKit


class BackgroundTaskManager : NSObject {
    
    var bgTaskIdList : NSMutableArray?
    var masterTaskId : UIBackgroundTaskIdentifier?
    
    override init() {
        super.init()
        self.bgTaskIdList = NSMutableArray()
        self.masterTaskId = UIBackgroundTaskInvalid
    }
    
    class func shared() -> BackgroundTaskManager? {
        struct Static {
            static var sharedBGTaskManager : BackgroundTaskManager?
            static var onceToken = 0
        }
        
        DispatchQueue.once(token: "\(Static.onceToken)") { _ in
            Static.sharedBGTaskManager = BackgroundTaskManager()
        }
        
        return Static.sharedBGTaskManager
    }
    
    func beginNewBackgroundTask() -> UIBackgroundTaskIdentifier? {
        let application : UIApplication = UIApplication.shared
        var bgTaskId : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
        
        let selector = #selector(application.beginBackgroundTask(expirationHandler:))
        if application.responds(to: selector) {
            print("RESPONDS TO SELECTOR")
            bgTaskId = application.beginBackgroundTask(expirationHandler: {
                print("background task \(bgTaskId as Int) expired\n")
            })
        }
        
        if self.masterTaskId == UIBackgroundTaskInvalid {
            self.masterTaskId = bgTaskId
            print("started master task \(self.masterTaskId!)\n")
        } else {
            // add this ID to our list
            print("started background task \(bgTaskId as Int)\n")
            self.bgTaskIdList!.add(bgTaskId)
            //self.endBackgr
        }
        return bgTaskId
    }
    
    func endBackgroundTask(){
        self.drainBGTaskList(all: false)
    }
    
    func endAllBackgroundTasks() {
        self.drainBGTaskList(all: true)
    }
    
    func drainBGTaskList(all: Bool) {
        //mark end of each of our background task
        let application: UIApplication = UIApplication.shared
        
        let endBackgroundTask : Selector = #selector(BackgroundTaskManager.endBackgroundTask)
        
        if application.responds(to: endBackgroundTask) {
            let count: Int = self.bgTaskIdList!.count
            for _ in (0..<count).reversed()  {
                let bgTaskId : UIBackgroundTaskIdentifier = self.bgTaskIdList!.object(at: 0) as! Int
                print("ending background task with id \(bgTaskId as Int)\n")
                application.endBackgroundTask(bgTaskId)
                self.bgTaskIdList!.removeObject(at: 0)
            }
            
            if self.bgTaskIdList!.count > 0 {
                print("kept background task id \(self.bgTaskIdList!.object(at: 0))\n")
            }
            
            if all == true {
                print("no more background tasks running\n")
                application.endBackgroundTask(self.masterTaskId!)
                self.masterTaskId = UIBackgroundTaskInvalid
            } else {
                print("kept master background task id \(self.masterTaskId!)\n")
            }
        }
    }
    
}
