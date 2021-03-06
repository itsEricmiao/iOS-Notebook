//
//  ViewController.swift
//  Commotion
//
//  Created by Eric Larson on 9/6/16.
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import CoreMotion

class ViewController: UIViewController {
    
    // MARK: =====Class Variables=====
    let activityManager = CMMotionActivityManager()
    let pedometer = CMPedometer()

    // MARK: =====UI Outlets=====
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var stepCounter: UISlider!
    @IBOutlet weak var debugLabel: UILabel!
    
    
    // MARK: =====UI Lifecycle=====
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.startActivityMonitoring()
        self.startPedometerMonitoring()
    }


    // MARK: =====Motion Methods=====
    func startActivityMonitoring(){
        // is activity is available
        if CMMotionActivityManager.isActivityAvailable(){
            // update from this queue (should we use the MAIN queue here??.... )
            self.activityManager.startActivityUpdates(to: OperationQueue.main)
            {(activity:CMMotionActivity?)->Void in
                // unwrap the activity and dispaly
                if let unwrappedActivity = activity {
                    print("%@",unwrappedActivity.description)
                    self.activityLabel.text = "Walking: \(unwrappedActivity.walking)"
                }
            }
        }
        
    }
    
    func startPedometerMonitoring(){
        // check if pedometer is okay to use
        if CMPedometer.isStepCountingAvailable(){
            pedometer.startUpdates(from: Date())
            {(pedData:CMPedometerData?, error:Error?)->Void in
                if let data = pedData {
                    
                    // display the output directly on the phone
                    DispatchQueue.main.async {
                        self.debugLabel.text = "\(data.description)"
                        self.stepCounter.value = data.numberOfSteps.floatValue
                    }
                }
            }
        }
    }


}

