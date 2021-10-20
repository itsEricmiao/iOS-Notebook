//
//  ModuleAViewController.swift
//  Lab3_moduleA
//
//  Created by Eric Miao on 10/16/21.
//

// UI Reference: https://medium.com/flawless-app-stories/custom-progress-bars-dc1c1c111751
import UIKit
import SwiftUI
import CoreMotion


class ModuleAViewController: UIViewController{
    
    @IBOutlet weak var progressPercentageLabel: UILabel!
    @IBOutlet weak var currentStepsLabel: UILabel!
    @IBOutlet weak var yesterdayStepsLabel: UILabel!
    @IBOutlet weak var goalStepsLabel: UILabel!
    @IBOutlet weak var userStateLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var stepsSinceAppLaunchLabel: UILabel!
    @IBOutlet weak var progressView: CircularProgressBar!
    @IBOutlet weak var progressSlider: UISlider!
    
    var goalSteps: Float = 500.0
    var todaySteps: Float = 0.0
    var yesterdaySteps: Float = 0.0
    var progress: Float = 0.0

    // MARK: ======Class Variables======
    let activityManager = CMMotionActivityManager()
    let pedometer = CMPedometer()
    
    
    // MARK: ======UI Lifecycle Methods======
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.bringSubviewToFront(progressPercentageLabel);
        self.startPedometerMonitoring()
        self.startActivityMonitoring()
        self.loadGoal()
        self.updateColors()
        self.findTodaySteps()
        self.findYesterdaySteps()
        self.showStat()
    }
    
    private func updateColors() {
        let colorRed: CGFloat = 250
        let colorGreen: CGFloat = 186
        let colorBlue: CGFloat = 218
        let gradientRed: CGFloat = 255
        let gradientGreen: CGFloat = 255
        let gradientBlue: CGFloat = 255
        
        let mainColor = UIColor(red: colorRed / 255, green: colorGreen / 255, blue: colorBlue / 255, alpha: 1)
        let gradient = UIColor(red: gradientRed / 255, green: gradientGreen / 255, blue: gradientBlue / 255, alpha: 1)
        progressView.color = mainColor
        progressView.gradientColor = gradient
        progressView.tintColor = mainColor
    }
    
    @IBAction func onProgressSliderChange(_ sender: UISlider) {
        self.goalSteps = sender.value
        saveGoal()
        self.goalSteps = max(self.goalSteps, 0)
        calculateStepsProgress()
        showStat()
    }
    
   
    
    
    func showStat(){
        DispatchQueue.main.async {
            self.currentStepsLabel.text = "Current Steps: " + String(Int(self.todaySteps))
            self.yesterdayStepsLabel.text = "Yesterday Steps: " + String(Int(self.yesterdaySteps))
            self.progressLabel.text = "Goal Progress: " + String(self.progress)
            self.goalStepsLabel.text = "Goal Steps: " + String(Int(self.goalSteps))
            let diff = self.goalSteps - self.todaySteps
            if diff < 0{
                self.progressPercentageLabel.text = "Woo-hoo! You have Reached your goal!"
            }else{
                self.progressPercentageLabel.text = String(Int(diff)) + " Steps and " + String(Int(100-(self.progress * 100))) + "% away From your Goal!"
            }
            
        }
    }
    
    func calculateStepsProgress(){
        self.progress = Float(self.todaySteps/self.goalSteps)
        print(self.progress, self.goalSteps, self.todaySteps)
        progressView.progress = CGFloat(self.progress)
    }
    
    
    func loadGoal() {
        if UserDefaults.standard.object(forKey:"Goal") == nil {
            UserDefaults.standard.set(self.goalSteps, forKey:"Goal")
        }
        self.goalSteps = UserDefaults.standard.object(forKey:"Goal") as! Float
    }
    
    func saveGoal(){
        UserDefaults.standard.set(self.goalSteps, forKey:"Goal")
    }
    
    
    func findTodaySteps(){
        let today = Calendar.current.startOfDay(for: Date())
        pedometer.queryPedometerData(from: today, to:Date(), withHandler: processTodayPedometerData)
    }
    
    func findYesterdaySteps(){
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = today.addingTimeInterval(Double(-1*60*60*24))
        pedometer.queryPedometerData(from:yesterday, to:today, withHandler:processYesterdayPedometerData)
    }
    
    func processTodayPedometerData(_ pedData:CMPedometerData?, error:Error?){
        if let steps = pedData?.numberOfSteps {
            self.todaySteps = steps.floatValue
        }
    }
    
    func processYesterdayPedometerData(_ pedData:CMPedometerData?, error:Error?){
        if let steps = pedData?.numberOfSteps {
            self.yesterdaySteps = steps.floatValue
        }
    }
    
    
    
    func startPedometerMonitoring(){
        // check if pedometer is okay to use
        if CMPedometer.isStepCountingAvailable(){
            pedometer.startUpdates(from: Date())
            {(pedData:CMPedometerData?, error:Error?)->Void in
                if let data = pedData {
                    DispatchQueue.main.async {
                        self.stepsSinceAppLaunchLabel.text = "Step Counter: " + data.numberOfSteps.stringValue
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
                    //                    print(unwrappedActivity.description)
                    if(unwrappedActivity.walking){
                        self.userStateLabel.text = "User State: Walking"
                    }
                    else if(unwrappedActivity.running){
                        self.userStateLabel.text = "User State: Running"
                    }
                    else if(unwrappedActivity.cycling){
                        self.userStateLabel.text = "User State: Cycling"
                    }
                    else if(unwrappedActivity.automotive){
                        self.userStateLabel.text = "User State: Driving"
                    }
                    else if(unwrappedActivity.stationary){
                        self.userStateLabel.text = "User State: Still"
                    }else{
                        self.userStateLabel.text = "User State: Unknown"
                    }
                }
            }
        }
    }
}
