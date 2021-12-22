//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import UIKit
import Metal





class LoudestFreqsAndGraphViewController: UIViewController {

    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 8192
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.graphView)
    }()
    let graphView = UIView(frame: CGRect(x: 0, y: 150, width: 100, height: 100))
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withFps: 10)

        audio.play()
        
        self.graphView.frame = CGRect(x: 0,
                                      y: 170,
                                      width: self.view.frame.width,
                                      height: self.view.frame.height/3)
        
        
        self.view.addSubview(graphView)
        // add in graphs for display
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
        
        graph?.addGraph(withName: "time",
            shouldNormalize: false,
            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
        
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateLabels),
            userInfo: nil,
            repeats: true)
       
    }
    @IBOutlet weak var loudestLabel: UILabel!
    
    @IBOutlet weak var secondLoudestLabel: UILabel!
    
    override func viewDidDisappear(_ animated: Bool) {
        audio.pause()
    }
    
        // periodically, update the graph with refreshed FFT Data
        @objc
        func updateLabels(){
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.loudestLabel.text = "Loudest Frequency: " + String(self.audio.loudestFreq)
                self.secondLoudestLabel.text = "Second Loudest Frequency: " + String(self.audio.secondLoudestFreq)
            }

        }
    
    @objc func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        
        self.graph?.updateGraph(
            data: self.audio.timeData,
            forKey: "time"
        )
    }
}

