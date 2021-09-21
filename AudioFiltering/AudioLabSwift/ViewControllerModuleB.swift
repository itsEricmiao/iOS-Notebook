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

    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
        
        
        graph?.addGraph(withName: "equalizer",
            shouldNormalize: true,
            numPointsInGraph: 20)

        
        graph?.addGraph(withName: "time",
            shouldNormalize: false,
            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)

        // Do any additional setup after loading the view.
    }
}
