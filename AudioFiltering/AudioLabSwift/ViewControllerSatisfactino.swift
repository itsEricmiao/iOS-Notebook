//
//  ViewControllerSatisfactino.swift
//  AudioLabSwift
//
//  Created by Joshua Sylvester on 9/16/21.
//  Copyright © 2021 Eric Larson. All rights reserved.
//

import UIKit
import Metal

class ViewControllerSatisfaction: UIViewController {

    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // add in graphs for display
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
        
        graph?.addGraph(withName: "equalizer",
            shouldNormalize: true,
            numPointsInGraph: 20)

        graph?.addGraph(withName: "time",
            shouldNormalize: false,
            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)

        
        
        
        
        // start up the audio model here, querying microphone
        audio.startSpeakerProcessing(withFps: 10)

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
    
    // periodically, update the graph with refreshed FFT Data
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )

        self.graph?.updateGraph(
            data: self.audio.timeData,
            forKey: "time"
        )

        self.graph?.updateGraph(
            data: self.audio.equalizerData,
            forKey: "equalizer"
        )
        
    }
}
