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
    
    let graphView = UIView(frame: CGRect(x: 0, y: 150, width: 100, height: 100))
    
    // Current state of the user
    let state = ["not gesturing", "gesturing toward", "gesturing away"]
    lazy var frequency = {
        return 15000
    }()
    
    // Audio bufffer size
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*16
    }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.graphView)
    }()
    
    
    func updateUserActionLabel(index: Int = 0){
        let currentState = state[index]
        DispatchQueue.main.async {
            self.userActionLabel.text = "User is " + currentState
        }
        print("User is " + currentState)
    }
    
    

    // When slider changes, the text on the label changes as well
    @IBAction func frequencySliderOnChange(_ sender: UISlider) {
        self.frequency = Int(sender.value)
        self.audio.sineFrequency = sender.value
        self.frequencyLabel.text = "Frequency: " + String(sender.value) + " Hz"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.graphView.frame = CGRect(x: 0, y: 170, width: self.view.frame.width, height: self.view.frame.height/3)
        self.view.addSubview(graphView)
        graph?.addGraph(withName: "microphoneData",
                        shouldNormalize: true,
                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)

        audio.startProcessingSinewaveForPlayback(withFreq: 15000)
        audio.startMicrophoneProcessing(withFps: 100)
        audio.play()

        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        audio.pause()
    }
    
    
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "microphoneData"
        )
    }
}
