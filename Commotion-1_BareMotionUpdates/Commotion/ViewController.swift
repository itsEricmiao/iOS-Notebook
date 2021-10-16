//
//  ViewController.swift
//  Commotion
//
//  Created by Eric Larson.
//  Copyright Eric Larson. All rights reserved.
//

import UIKit
import CoreMotion

class ViewController: UIViewController {
    @IBOutlet weak var activityLabel: UILabel!
    
    // MARK: ======Class Variables======
    let activityManager = CMMotionActivityManager()

    // MARK: ======UI Lifecycle Methods======
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startActivityMonitoring()
    }

    // MARK: ======Motion Methods======
    func startActivityMonitoring(){
        // if active, let's start processing
        if CMMotionActivityManager.isActivityAvailable(){
            // assign updates to the main queue for activity
            self.activityManager.startActivityUpdates(to: OperationQueue.main)
            {(activity:CMMotionActivity?)->Void in
                if let unwrappedActivity = activity {
                                        
                    print(unwrappedActivity.description)
                    if(unwrappedActivity.walking){
                        self.activityLabel.text = "Walking, conf: \(unwrappedActivity.confidence.rawValue)"
                    }
                    else if(unwrappedActivity.running){
                        self.activityLabel.text = "Running, conf: \(unwrappedActivity.confidence.rawValue)"
                    }
                    else{
                        self.activityLabel.text = "Not Walking or Running"
                    }
                }
            }
        }
        
    }


}

