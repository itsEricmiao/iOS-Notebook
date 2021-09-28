//
//  DopplerHelper.swift
//  AudioLabSwift
//
//  Created by Eric Miao on 9/26/21.
//  Copyright © 2021 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class DopplerHelper{
    var fftData:[Float] = []
    var frequency: Float = 0.0
    var state: Int = 0
    
    var prevLeftPeak: Float = 0.0
    var prevRightPeak: Float = 0.0
    var peak: Float = 0.0
    
    var hertzBetweenSamples: Float = 0.0
    var fftCount: Int = 0
    var fftFrames: Int = 0
    
    var allLeftPeaks: [Float] = []
    var allRightPeaks: [Float] = []
    var prevDiff: [Float] = []
    
    func setFFTData(inputArr: [Float]){
        fftData = inputArr
        fftCount = fftData.count
        fftFrames = fftCount * 2
    }
    
    func setFrequency(inputVal: Float){
        frequency = inputVal
        hertzBetweenSamples = frequency/Float(fftFrames)
    }
    
    func getUserState()->Int{
        return self.state
    }
    
    
    func analyze(){
        let bin = 48000/self.fftFrames
        let index = Int(self.frequency/Float(bin))
        
        if !self.fftData[0].isInfinite{
            let leftArr = Array.init(self.fftData[index-100...index-10])
            let rightArr = Array.init(self.fftData[index+10...index+100])
            
            let leftPeak = self.takeLocalMaximal(targetArr: leftArr)
            let rightPeak = self.takeLocalMaximal(targetArr: rightArr)

            if allRightPeaks.count > 1{
                let lastLPeak = allLeftPeaks.last!
                let lastRPeak = allRightPeaks.last!
                
                print(lastLPeak, leftPeak, lastLPeak - leftPeak)
                print(lastRPeak, rightPeak, lastRPeak - rightPeak)
                
                let diffR = rightPeak - lastRPeak
                let diffL = leftPeak - lastLPeak
                
                if (diffR > 0 || diffL < 0){
                    self.state = 1
                }
                else if (diffR < 0 || diffL > 0){
                    self.state = 2
                }
                else{
                    self.state = 0
                }
            }
            
            allLeftPeaks.append(leftPeak)
            allRightPeaks.append(rightPeak)
            
            print()
        }
    }
    
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
    
    
    func reset(){
        self.fftData = []
        self.frequency = 0.0
        self.state = 0
    }
}
