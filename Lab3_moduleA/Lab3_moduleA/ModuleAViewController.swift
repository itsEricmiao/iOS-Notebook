//
//  ModuleAViewController.swift
//  Lab3_moduleA
//
//  Created by Eric Miao on 10/16/21.
//

import UIKit
import CoreMotion

class ModuleAViewController: UIViewController {

    @IBOutlet weak var currentStepsLabel: UILabel!
    @IBOutlet weak var prevStepsLabel: UILabel!
    @IBOutlet weak var goalLabel: UILabel!
    @IBOutlet weak var userActivityLabel: UILabel!
    @IBOutlet weak var userGoalSlider: UISlider!
    @IBOutlet weak var setGoalButton: UIButton!
    
    
    // MARK: ======Class Variables======
    let activityManager = CMMotionActivityManager()
    let pedometer = CMPedometer()
    
    
    // MARK: ======UI Lifecycle Methods======
    override func viewDidLoad() {
        super.viewDidLoad()
        findPrevSteps()
        startPedometerMonitoring()
        startActivityMonitoring()
        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func goalSliderOnChanged(_ sender: UISlider!) {
        
    }
    
    
    @IBAction func setGoalButtonPressed(_ sender: UIButton!) {
        
    }
    
    func findPrevSteps(){
        if CMPedometer.isStepCountingAvailable() {
            let calendar = Calendar.current
            pedometer.queryPedometerData(from: calendar.startOfDay(for: Date()), to: Date()) { (data, error) in
                print(data)
            }
        }
    }
    
    
    func startPedometerMonitoring(){
        // check if pedometer is okay to use
        if CMPedometer.isStepCountingAvailable(){
            pedometer.startUpdates(from: Date())
            {(pedData:CMPedometerData?, error:Error?)->Void in
                if let data = pedData {
                    DispatchQueue.main.async {
                        self.currentStepsLabel.text = data.numberOfSteps.stringValue
                    }
                }
            }
        }
    }
    
    
    
    func startActivityMonitoring(){
        // if active, let's start processing
        if CMMotionActivityManager.isActivityAvailable(){
            // assign updates to the main queue for activity
            self.activityManager.startActivityUpdates(to: OperationQueue.main)
            {(activity:CMMotionActivity?)->Void in
                if let unwrappedActivity = activity {
                    print(unwrappedActivity.description)
                    if(unwrappedActivity.walking){
                        self.userActivityLabel.text = "Walking, conf: \(unwrappedActivity.confidence.rawValue)"
                    }
                    else if(unwrappedActivity.running){
                        self.userActivityLabel.text = "Running, conf: \(unwrappedActivity.confidence.rawValue)"
                    }
                    else if(unwrappedActivity.cycling){
                        self.userActivityLabel.text = "Cycling, conf: \(unwrappedActivity.confidence.rawValue)"
                    }
                    else if(unwrappedActivity.automotive){
                        self.userActivityLabel.text = "Driving, conf: \(unwrappedActivity.confidence.rawValue)"
                    }
                    else if(unwrappedActivity.stationary){
                        self.userActivityLabel.text = "Still"
                    }else{
                        self.userActivityLabel.text = "Unknown, conf: \(unwrappedActivity.confidence.rawValue)"
                    }
                }
            }
        }
    }


}
