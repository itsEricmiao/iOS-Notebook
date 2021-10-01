//
//  ViewControllerModuleB.swift
//  AudioLabSwift
//
//  Created by Eric Miao on 9/21/21.
//  Copyright © 2021 Eric Larson. All rights reserved.
//

import UIKit
import Metal

class ViewControllerModuleB: UIViewController {

    @IBOutlet weak var userActionLabel: UILabel!
    @IBOutlet weak var frequencyLabel: UILabel!
    @IBOutlet weak var audioFrequencySlider: UISlider!
    @IBOutlet weak var startAnalyzerButton: UIButton!
    
    let graphView = UIView(frame: CGRect(x: 0, y: 150, width: 100, height: 100))
    var ifPlay = false
    let states = ["not gesturing", "gesturing forward", "gesturing away"]

    var currentState = "not gesturing" // Init state of the user
    var frequency = Float(15000) // Init frequency as 15000 hz
    
    // Audio bufffer size
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.graphView)
    }()
    
    // function for updating the label that shows user's current action
    func updateUserActionLabel(index: Int = 0){
        let currentState = states[index]
        DispatchQueue.main.async {
            self.userActionLabel.text = "User is " + currentState
        }
    }
    
    // when the user press the button, the button text would change
    @IBAction func startAnalyzerButtonPressed(_ sender: Any) {
        if (!ifPlay){
            self.startDetectingDopplerProcess()
            ifPlay = !self.ifPlay
            frequencyLabel.text = "Frequency: " + String(self.frequency) + " Hz"
            startAnalyzerButton.setTitle("Stop", for: .normal)
            
        }else{
            self.stopDetectingDopplerProcess()
            ifPlay = false
            startAnalyzerButton.setTitle("Start", for: .normal)
        }
    }
    
    
    // When slider changes, the text on the label changes as well
    @IBAction func frequencySliderOnChange(_ sender: UISlider) {
        self.frequency = sender.value
        self.audio.sineFrequency = sender.value
        self.frequencyLabel.text = "Frequency: " + String(sender.value) + " Hz"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.graphView.frame = CGRect(x: 0,
                                      y: 170,
                                      width: self.view.frame.width,
                                      height: self.view.frame.height/3)
        
        self.view.addSubview(graphView)
        graph?.addGraph(withName: "microphoneData",
                        shouldNormalize: true,
                        numPointsInGraph: 201)
        
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        self.stopDetectingDopplerProcess()
    }
    
    // start function for the doppler process
    @objc
    func startDetectingDopplerProcess(){
        audio.startProcessingSinewaveForPlayback(withFreq: self.frequency)
        audio.startMicrophoneProcessing(withFps: 100)
        audio.play()
    }
    
    // end function for the doppler process or when the user press stop
    func stopDetectingDopplerProcess(){
        self.audio.pause()
        self.audio.resetDopplerHelper()
    }
    
    // key function that keep updating the graph and the user state label
    @objc func updateGraph(){
        let bin = self.audio.samplingRate/Float(self.audio.fftData.count*2)
        let index = Int(self.frequency/Float(bin))
        print(index)
        let zoomed = Array.init(self.audio.fftData[index-100...index+100])
        self.currentState = self.states[self.audio.getUserState()]
        self.updateUserActionLabel(index: self.audio.getUserState())
        self.graph?.updateGraph(
            data: zoomed,
            forKey: "microphoneData"
        )
    }
}
