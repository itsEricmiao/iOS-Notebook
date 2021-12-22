//
//  ModuleAViewController.swift
//  Lab3_moduleA
//
//  Created by Eric Miao, Joshua Sylvester, Canon Ellis on 10/15/21.
//

// Circular progress bar UI Reference: www.simpleswiftguide.com/how-to-build-a-circular-progress-bar-in-swiftui
import UIKit
import SwiftUI
import CoreMotion


class ModuleAViewController: UIViewController{
    
    @IBOutlet weak var progressPercentageLabel: UILabel! // Big title on the center of the screen that tracks current user step progress
    @IBOutlet weak var currentStepsLabel: UILabel! // shows current step counts
    @IBOutlet weak var yesterdayStepsLabel: UILabel! // shows step counts from yesterday
    @IBOutlet weak var goalStepsLabel: UILabel! // shows goal step counts set by user (or loaded from NSDefault)
    @IBOutlet weak var userStateLabel: UILabel! // show suser current activity state
    @IBOutlet weak var progressLabel: UILabel! // shows the current progress of user in %
    @IBOutlet weak var progressView: CircularProgressBar! // circular progress bar with animation
    @IBOutlet weak var progressSlider: UISlider! // slider for user to set up the goal steps
    @IBOutlet weak var startGameButton: UIButton! // button for start playing the game
    
    @IBOutlet weak var activityImage: UIImageView!
    
    // MARK: ======Class Variables======
    let activityManager = CMMotionActivityManager()
    let pedometer = CMPedometer()
    
    
    
    
    // goal steps: initial value is 500
    var todaySteps: Float = 0.0 // today's steps from CMPedometer
    var yesterdaySteps: Float = 0.0 // yesterday's steps from CMPedometer
    var progress: Float = 0.0
    var goalSteps: Float = 500.0
        
    
    
    // progress value: equals to today's step / goal steps
    
    
    
    // MARK: ======UI Lifecycle Methods======
    override func viewDidLoad() {
        super.viewDidLoad()
        self.progressSlider.value = UserDefaults.standard.object(forKey:"Goal") as! Float
        self.loadGoal()
        self.startPedometerMonitoring()
        self.startActivityMonitoring()
        self.findTodaySteps()
        self.findYesterdaySteps()
        self.updateColors()
    }
    
    
    
    // Below function set the color for the progress bar
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
    
    
    // when progress bar slider changes
    @IBAction func onProgressSliderChange(_ sender: UISlider) {
        self.goalSteps = sender.value
        self.goalStepsLabel.text = "Goal Steps: " + String(self.goalSteps)
        calculateStepsProgress()
        saveGoal()
        
    }
    
    
    
    // use queue to update pretty much all labels on our UI
    // calculate progress of user -> this function is called when the value for goal steps or the value of current steps is changed
    func calculateStepsProgress(){
        self.progress = Float(self.todaySteps/self.goalSteps)
        progressView.progress = CGFloat(self.progress)
        self.setupRunGameButton()
        DispatchQueue.main.async {
            self.progressLabel.text = "Goal Progress: " + String((self.progress * 100)) + "%"
            let diff = self.goalSteps - self.todaySteps
            if diff < 0{
                self.progressPercentageLabel.text = "Woo-hoo! You have Reached your goal!"
            }else{
                self.progressPercentageLabel.text = String(Int(diff)) + " Steps and " + String(Int(100-(self.progress * 100))) + "% away From your Goal!"
            }
        }
    }
    
    // loading goal step value from userdefault
    func loadGoal() {
        if UserDefaults.standard.object(forKey:"Goal") == nil {
            UserDefaults.standard.set(self.goalSteps, forKey:"Goal")
        }
        
        self.goalSteps = UserDefaults.standard.object(forKey:"Goal") as! Float
        self.progress = Float(self.todaySteps) / Float(self.goalSteps)
        DispatchQueue.main.async {
            self.goalStepsLabel.text = "Goal Steps: " + String(self.goalSteps)
        }
        print("loadGoal:", self.todaySteps, self.goalSteps)
    }
    
    func findGoal() -> Float{
        if UserDefaults.standard.object(forKey:"Goal") == nil {
            UserDefaults.standard.set(self.goalSteps, forKey:"Goal")
        }
        
        return UserDefaults.standard.object(forKey:"Goal") as! Float
    }
    
    // save goal step value to userdefault
    func saveGoal(){
        UserDefaults.standard.set(self.goalSteps, forKey:"Goal")
    }
    
    // find today's step from CMPedometer
    func findTodaySteps(){
        let today = Calendar.current.startOfDay(for: Date())
        pedometer.queryPedometerData(from: today, to:Date(), withHandler: processTodayPedometerData)
    }
    
    // find yesterday's step from CMPedometer
    func findYesterdaySteps(){
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = today.addingTimeInterval(Double(-1*60*60*24))
        pedometer.queryPedometerData(from:yesterday, to:today, withHandler:processYesterdayPedometerData)
    }
    
    // callback function for findTodaySteps()
    func processTodayPedometerData(_ pedData:CMPedometerData?, error:Error?){
        if let steps = pedData?.numberOfSteps {
            self.todaySteps = steps.floatValue
            DispatchQueue.main.async {
                self.currentStepsLabel.text = "Current Steps: " + String(Int(self.todaySteps))
                self.calculateStepsProgress()
            }
        }
    }
    
    // callback function for findYesterdaySteps()
    func processYesterdayPedometerData(_ pedData:CMPedometerData?, error:Error?){
        if let steps = pedData?.numberOfSteps {
            self.yesterdaySteps = steps.floatValue
            DispatchQueue.main.async {
                self.yesterdayStepsLabel.text = "Yesterday Steps: " + String(Int(self.yesterdaySteps))
                self.calculateStepsProgress()
            }
        }
    }
    
    
    // start CMPedometer monitoring
    func startPedometerMonitoring(){
        // check if pedometer is okay to use
        if CMPedometer.isStepCountingAvailable(){
            pedometer.startUpdates(from: Date())
            {(pedData:CMPedometerData?, error:Error?)->Void in
                if let data = pedData {
                    self.todaySteps += Float(truncating: data.numberOfSteps)
                    DispatchQueue.main.async {
                        self.currentStepsLabel.text = "Current Steps: " + String(Int(self.todaySteps))
                    }
                }
            }
        }
    }
    
    
    // start activity monitoring
    func startActivityMonitoring(){
        // if active, let's start processing
        if CMMotionActivityManager.isActivityAvailable(){
            // assign updates to the main queue for activity
            self.activityManager.startActivityUpdates(to: OperationQueue.main)
            {(activity:CMMotionActivity?)->Void in
                if let unwrappedActivity = activity {
                    if(unwrappedActivity.walking){
                        self.userStateLabel.text = "User State: Walking"
                        self.activityImage.image = UIImage(named:"walking")
                    } else if(unwrappedActivity.running){
                        self.userStateLabel.text = "User State: Running"
                        self.activityImage.image = UIImage(named:"running")
                    } else if(unwrappedActivity.cycling){
                        self.userStateLabel.text = "User State: Cycling"
                        self.activityImage.image = UIImage(named:"cycling")
                    } else if(unwrappedActivity.automotive){
                        self.userStateLabel.text = "User State: Driving"
                        self.activityImage.image = UIImage(named:"driving")
                    } else if(unwrappedActivity.stationary){
                        self.userStateLabel.text = "User State: Still"
                        self.activityImage.image = UIImage(named:"still")
                    } else{
                        self.userStateLabel.text = "User State: Unknown"
                        self.activityImage.image = UIImage(named:"unknown")
                    }
                }

            }
        }
    }
    
    // grey out game button when user hasn't reached goal steps
    // enable game button when user reaches goal steps
    func setupRunGameButton(){
        DispatchQueue.main.async {
            self.startGameButton.isEnabled = false
            if self.yesterdaySteps >= self.goalSteps{
                self.startGameButton.isEnabled = true
            }
        }
    }
    
    // handle segue to game
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // here is where we set an image name to the new view controller
        // this image should be in the image.assets directory
        
        let vc = segue.destination as! GameViewController
        vc.yesterdaySteps = yesterdaySteps
    }
}
