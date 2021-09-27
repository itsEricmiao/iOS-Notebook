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
    
    var allLeftMax: [Float] = []
    var allRightMax: [Float] = []
    
    
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
        let peak = fftData.max()!
        let low = fftData.min()!
        var peakIndex = -1
        if let p = fftData.firstIndex(of: peak) {
            peakIndex = p
        }
        
        var leftMax = low
        var rightMax = low
        var lD = 0
        var rD = 0
        
        if (peakIndex > 0){
            for i in 0...peakIndex-1{
                if (leftMax < fftData[i]){
                    leftMax = fftData[i]
                    lD = peakIndex - i
                }
            }
        }
       
        if (peakIndex < fftData.count-1){
            for i in peakIndex+1...fftData.count-1{
                if (rightMax < fftData[i]){
                    rightMax = fftData[i]
                    rD = i - peakIndex
                }
            }
        }
        
        
        print("peak ", String(peak), "peak index ", String(peakIndex))
        print("left Max: ", String(leftMax), "right Max: ", String(rightMax))
        print("LM distance:",String(lD),  "RM distance", String(rD))
        print()
        
        if (rightMax > leftMax && rD < lD){
            print("Moving toward")
        }
        else if (rightMax < leftMax && rD > lD){
            print("Moving Away")
        }else{
            print("Static")
        }
    }
    
    func analyze2(){
//        BufferSize = 2048
//        Frequency = 15000 -> peak?
//        bin = 48000/2048
//        index = 15000/bin = 640
//
//        startAt -> 640
//        goLeft -> find leftMax
//        goRight -> find rightMax
        
        let bufferSize = self.fftData.count * 2
        let bin = 48000/bufferSize
        let index = Int(self.frequency/Float(bin))
        print(self.frequency)
        print(index," ", bufferSize/2)
        
        
        let leftArr = Array.init(self.fftData[index-100...index-1])
        let rightArr = Array.init(self.fftData[index+1...index+100])
        
        var leftMax: Float = .nan
        var leftIndex: vDSP_Length = 0
        
        var rightMax: Float = .nan
        var rightIndex: vDSP_Length = 0
        let subArrayLength = vDSP_Length(rightArr.count)
        let stride = vDSP_Stride(1)
        
        vDSP_maxvi(leftArr, stride, &leftMax, &leftIndex, subArrayLength)
        vDSP_maxvi(rightArr, stride, &rightMax, &rightIndex, subArrayLength)
        
        allLeftMax.append(leftMax)
        allRightMax.append(rightMax)
        
        print("left: ", allLeftMax)
        print("right: ",allRightMax)
        print()
        
    }
    
    func reset(){
        self.fftData = []
        self.frequency = 0.0
        self.state = 0
    }
    
    
    
    
}
