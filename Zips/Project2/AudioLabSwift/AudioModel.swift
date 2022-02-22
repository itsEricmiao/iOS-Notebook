//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    var loudestFreq: Float
    var secondLoudestFreq: Float
    var loudestAmplitude: Float
    var secondLoudestAmplitude: Float
    
    
    // MARK: Adding by Eric
    var helper = DopplerHelper()
    var equalizerData: [Float]
    var samplingRate: Float = 0.0
    
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double, option: Int = 0){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            
            if option == 1{
                Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                     selector: #selector(self.runEveryIntervalB),
                                     userInfo: nil,
                                     repeats: true)
                
            }else{
                // Handle 200 ms constraint ??? Here it should be 0.1 seconds ???
                Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                     selector: #selector(self.runEveryInterval),
                                     userInfo: nil,
                                     repeats: true)
            }
            
        }
    }
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        loudestFreq = -100000.0
        secondLoudestFreq = -1000000.0
        loudestAmplitude = -1000000
        secondLoudestAmplitude = -1000000
        equalizerData = Array.init(repeating: 0.0, count: 20)
        samplingRate = Float(self.audioManager!.samplingRate)
        
    }
    
    
   
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    func pause() {
        self.audioManager?.inputBlock = nil
        self.audioManager?.outputBlock = nil
        if let manager = self.audioManager{
            manager.pause()
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    private lazy var outputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numOutputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            print("does this print")
            self.findLoudestFreqs()
            
            
        }
    }
    
    // MARK: Eric: Adding methods from Larson's class assignment:
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        sineFrequency = withFreq
        // Two examples are given that use either objective c or that use swift
        //   the swift code for loop is slightly slower thatn doing this in c,
        //   but the implementations are very similar
        //self.audioManager?.outputBlock = self.handleSpeakerQueryWithSinusoid // swift for loop
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency) // c for loop
    }
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    
    //    _     _     _     _     _     _     _     _     _     _
    //   / \   / \   / \   / \   / \   / \   / \   / \   / \   /
    //  /   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/
    
    
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
        didSet{
            // if using swift for generating the sine wave: when changed, we need to update our increment
            //phaseIncrement = Float(2*Double.pi*sineFrequency/audioManager!.samplingRate)
            
            // if using objective c: this changes the frequency in the novocaine block
            if let manager = self.audioManager {
                manager.sineFrequency = sineFrequency
            }
        }
    }
    // SWIFT SINE WAVE
    // everything below here is for the swift implementation
    // this can be deleted when using the objective c implementation
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        if let arrayData = data{
            var i = 0
            while i<numFrames{
                arrayData[i] = sin(phase)
                phase += phaseIncrement
                if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                i+=1
            }
        }
    }
    
    func getUserState()->Int{
        return helper.getUserState()
    }
    
    func resetDopplerHelper(){
        self.helper.reset()
    }
    
    @objc
    private func runEveryIntervalB(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            helper.setFFTData(inputArr: self.fftData)
            helper.setSamplingRate(inputRate: self.samplingRate)
            helper.setFrequency(inputVal: self.sineFrequency)
            helper.analyze()
        }
    }
    // MARK: Eric: Adding methods from Larson's class assignment ends here
    
    
    // We will go through the fftData in windows of less than 50Hz and find the two highest peaks in the amplitudes.
    // Then we set self.loudestFreq and self.secondLoudestFreq to be those two peaks
    // Still to do: get the +-3Hz accuracy
    private func findLoudestFreqs() {
        let window = 15
        for i in 0..<fftData.count - window {
            let arrWindow: [Float] = [Float](fftData[i..<i + window])
            var loudestAmplitudeInWindow: Float = .nan
            var loudestFreqInWindow: vDSP_Length = 0
            vDSP_maxvi(arrWindow, 1, &loudestAmplitudeInWindow, &loudestFreqInWindow, vDSP_Length(arrWindow.count))
            if loudestFreqInWindow == window / 2 { // temporarily hardocded
                if loudestAmplitudeInWindow > loudestAmplitude { // if true we have our new loudest freq
                    let f2 = Float(Float(i+7) * Float(samplingRate / Float(BUFFER_SIZE)))
                    loudestFreq = interpolate(f2: f2, deltaF: Float(samplingRate / Float(BUFFER_SIZE)), m1: fftData[i + ( window / 2 ) - 1], m2: fftData[i +  (window / 2) ], m3: fftData[i + ( window / 2 ) + 1])
                    loudestAmplitude = fftData[i +  window / 2 ]
                } else if loudestAmplitudeInWindow > secondLoudestAmplitude { // if true we have our new second loudest freq
                    let f2 = Float(Float(i +  window / 2 ) * Float(samplingRate / Float(BUFFER_SIZE)))
                    // TODO: NEED TO ADD COMMENTS HERE FOR WHY WE DID THIS HACK
                    if abs(f2 - loudestFreq) >= 45 {
                        secondLoudestFreq = interpolate(f2: f2, deltaF: Float(samplingRate / Float(BUFFER_SIZE)), m1: fftData[i + ( window / 2 ) - 1], m2: fftData[i +  window / 2 ], m3: fftData[i +  (window / 2) + 1])
                        secondLoudestAmplitude = fftData[i +  window / 2 ]
                    }
                }
            }
        }
    }
    
    private func interpolate(f2:Float, deltaF: Float, m1:Float, m2:Float, m3:Float)->Float {
        let numerator:Float = (m1 - m3) * deltaF
        let denominator:Float = (m3 - 2 * m2 + m1) * 2
        let quotient:Float = numerator / denominator
        let result = f2 + quotient
        return result
    }

    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
}



//
//        let window = 5
//
//        for i in 0..<fftData.count - window{
//            print(fftData[i])
////            var arrWindow: [Float] = [Float](fftData[i..<i + window])
////            var loudestAmplitudeInWindow: Float = .nan
////            var loudestFreqInWindow: vDSP_Length = 0
////            vDSP_maxvi(arrWindow, 1, &loudestAmplitudeInWindow, &loudestFreqInWindow, vDSP_Length(arrWindow.count))
////            if loudestFreqInWindow == 2 { // temporarily hardocded
////
////                if loudestAmplitudeInWindow < loudestAmplitude {
////                    loudestFreq = (i + 2) * Int(48000 / BUFFER_SIZE)
////                    loudestAmplitude = fftData[i]
////                } else if loudestAmplitudeInWindow > secondLoudestAmplitude {
////                    secondLoudestFreq = (i + 2) * Int(48000 / BUFFER_SIZE)
////                    secondLoudestAmplitude = fftData[i + 2]
////                }
////            }
//        }
