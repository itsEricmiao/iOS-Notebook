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
    var fftDataSqr:[Float]
    var equalizerData: [Float]
    var helper = DopplerHelper()
    
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        fftDataSqr = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        equalizerData = Array.init(repeating: 0.0, count: 20)
    }
    
    
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                 selector: #selector(self.runEveryInterval),
                                 userInfo: nil,
                                 repeats: true)
        }
    }
    
    // public function for playing music out of speakers
    func startSpeakerProcessing(withFps: Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
            
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                                 selector: #selector(self.runEveryIntervalOutput),
                                 userInfo: nil,
                                 repeats: true)
        }
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
    // MARK: Eric: Adding methods from Larson's class assignment ends here
    
    
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
            
            
            let equalizerBinLength = BUFFER_SIZE/(2*20)
            
            equalizerData = Array.init(repeating: 0.0, count: 20)
            
            var tempMax = Float(-100)
            var equalizerDataCounter = 0
            for i in 0..<fftData.count {
                if i % equalizerBinLength == 0 && i != 0 {
                    equalizerData[equalizerDataCounter] = tempMax
                    equalizerDataCounter += 1
                    tempMax = Float(-100)
                }
                
                if fftData[i] > tempMax {
                    tempMax = fftData[i]
                }
            }
            
            helper.setFFTData(inputArr: self.fftData)
            helper.setFrequency(inputVal: self.sineFrequency)
            helper.analyze2()
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    
    func getUserState()->Int{
        return helper.getUserState()
    }
    
    @objc
    private func runEveryIntervalOutput(){
        if outputBuffer != nil {
            // copy time data to swift array
            self.outputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))

            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            let equalizerBinLength = BUFFER_SIZE/(2*20)
            
            equalizerData = Array.init(repeating: 0.0, count: 20)
            
            var tempMax = Float(-100)
            var equalizerDataCounter = 0
            for i in 0..<fftData.count {
                if i % equalizerBinLength == 0 && i != 0 {
                    equalizerData[equalizerDataCounter] = tempMax
                    equalizerDataCounter += 1
                    tempMax = Float(-100)
                }
                
                if fftData[i] > tempMax {
                    tempMax = fftData[i]
                }
            }
            
        }
    }
    
    private lazy var fileReader:AudioFileReader? = {
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3") {
            var tmpFileReader: AudioFileReader? = AudioFileReader.init(audioFileURL: url, samplingRate: Float(audioManager!.samplingRate), numChannels: audioManager!.numOutputChannels)
            tmpFileReader!.currentTime = 0.0
            print("Audio file successfully loaded for \(url)")
            return tmpFileReader
        } else {
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    
    private func handleSpeakerQueryWithAudioFile(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        if let file = self.fileReader {
            file.retrieveFreshAudio(data, numFrames: numFrames, numChannels: numChannels)
            self.outputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
        }
    }
}
