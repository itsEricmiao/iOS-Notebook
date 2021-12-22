
//  DopplerHelper.swift
//  AudioLabSwift
//
//  Created by Eric Miao on 9/26/21.
//  Copyright © 2021 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class DopplerHelper{
    var fftData:[Float] = []     // fftDate from the audio manager
    var frequency: Float = 0.0   // current sinewave frequency
    var state: Int = 0           // variable for user state - 0: not moving, 1: moving forward, 2: moving backward
    
    var fftFrames: Int = 0
    var samplingRate: Float = 0.0
    
    // setter for fftDate array
    func setFFTData(inputArr: [Float]){
        fftData = inputArr
        fftFrames = inputArr.count * 2
    }
    
    // setter for sampling rate
    func setSamplingRate(inputRate: Float){
        self.samplingRate = inputRate
    }
    
    // setter for frequency
    func setFrequency(inputVal: Float){
        self.frequency = inputVal
    }
    
    // getter for user state
    func getUserState()->Int{
        return self.state
    }
    
    
    /*
        Analyze function that does the following steps:
        1. Split the fftData array into two portion:
                one from the left side of the peak index and one from the right side of the peak index
        2. Using local maximal function to take the maximals on both arrays
        3. Compare the two maximal and determine the state of the user:
             leftPeak > rightPeak: hand moving backward
             rightPeak > leftPeak: hand moving forward
             (I also set a threshold value here to make sure we can detect when user hand is not moving)
        4. Update the state index variable so the UI can gets updated too
     */
    
    func analyze(){
        let bin = self.samplingRate/Float(self.fftFrames)
        let index = Int(self.frequency/Float(bin))
        
        if !self.fftData[0].isInfinite{
            let leftArr = Array.init(self.fftData[index-20...index-2])
            let rightArr = Array.init(self.fftData[index+2...index+20])
            
            let leftPeak = self.takeLocalMaximal(targetArr: leftArr)
            let rightPeak = self.takeLocalMaximal(targetArr: rightArr)
            
            let diff = leftPeak - rightPeak
            if (leftPeak > rightPeak && diff > -10){
                self.state = 2
            }else if (leftPeak < rightPeak && diff < -20){
                self.state = 1
            }else{
                self.state = 0
            }
        }
    }
    
//    TODO: Can we delete this?
    func analyzeUsingWindowMaximals(){
        let bin = self.samplingRate/Float(self.fftFrames)
        let index = Int(self.frequency/Float(bin))
        if !self.fftData[0].isInfinite{
            let leftArr = Array.init(self.fftData[index-101...index-1])
            let rightArr = Array.init(self.fftData[index+1...index+101])
            
            let leftPeaks = self.useWindowSliderToFindLocalMaximal(targetArr: leftArr, windowSize: 10)
            let rightPeaks = self.useWindowSliderToFindLocalMaximal(targetArr: rightArr, windowSize: 10)
            
            let leftPeak = vDSP.mean(leftPeaks)
            let rightPeak = vDSP.mean(rightPeaks)
            
            let diff = leftPeak - rightPeak
            
            print(leftPeak, rightPeak, diff)

            if (leftPeak > rightPeak && diff > -10){
                self.state = 2
            }else if (leftPeak < rightPeak && diff < -20){
                self.state = 1
            }else{
                self.state = 0
            }
        }
        
    }
    
    /*
      [Float]: targetArr: our fftData or zoomed fftData
      returns the local maximal within that array
     */
    func takeLocalMaximal(targetArr: [Float])->Float{
        var maxVal: Float = .nan
        var maxIndex: vDSP_Length = 0
        let targetArrLength = vDSP_Length(targetArr.count)
        let stride = vDSP_Stride(1)
        vDSP_maxvi(targetArr, stride, &maxVal, &maxIndex, targetArrLength)
        return maxVal
    }
    
    
    /*
      [Float]: targetArr: our fftData or zoomed fftData
      Int:     windowSize: the size for our sliding window -> has to be an even number
      (I ended up not using this function but I am still gonna leave it here)
     */
    func useWindowSliderToFindLocalMaximal(targetArr: [Float], windowSize: Int)->[Float]{
        var peaks = [Float]()
        let length = targetArr.count
        for i in 0...length-windowSize-1{
            let curArray = Array.init(targetArr[i...i+windowSize])
            var maxVal: Float = .nan
            var maxIndex: vDSP_Length = 0
            let curArrayLength = vDSP_Length(curArray.count)
            let stride = vDSP_Stride(1)
            vDSP_maxvi(curArray, stride, &maxVal, &maxIndex, curArrayLength)
            if (maxIndex == windowSize/2){
                peaks.append(maxVal)
            }
        }
        return peaks
    }
    
    //function for reset DopplerHelper data
    func reset(){
        self.fftData = []
        self.frequency = 0.0
        self.state = 0
    }
}
