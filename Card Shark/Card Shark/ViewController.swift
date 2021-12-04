//
//  ViewController.swift
//  Card Shark
//
//  Created by Eric Miao on 12/1/21.
//

import UIKit
import AVFoundation
import CoreHaptics

// Reference for camera feed: stackoverflow.com/questions/28487146/how-to-add-live-camera-preview-to-uiview
// Reference for using CoreHaptics: www.hackingwithswift.com/example-code/core-haptics/how-to-play-custom-vibrations-using-core-haptics

class ViewController: UIViewController{
    
    // initialize haptic engine
    var engine: CHHapticEngine?
    
    // views for the camera feed
    var previewView : UIView!
    var boxView:UIView!
    let myButton: UIButton = UIButton()

    
    //Camera Capture requiered properties
    var videoDataOutput: AVCaptureVideoDataOutput!
    var videoDataOutputQueue: DispatchQueue!
    var previewLayer:AVCaptureVideoPreviewLayer!
    var captureDevice : AVCaptureDevice!
    let session = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        //
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        previewView = UIView(frame: CGRect(x: 0,
                                           y: 0,
                                           width: UIScreen.main.bounds.size.width,
                                           height: UIScreen.main.bounds.size.height))
        previewView.contentMode = UIView.ContentMode.scaleAspectFit
        view.addSubview(previewView)

        //Add a view on top of the cameras' view
        boxView = UIView(frame: self.view.frame)

        myButton.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        myButton.backgroundColor = UIColor.red
        myButton.layer.masksToBounds = true
        myButton.setTitle("press me", for: .normal)
        myButton.setTitleColor(UIColor.white, for: .normal)
        myButton.layer.cornerRadius = 20.0
        myButton.layer.position = CGPoint(x: self.view.frame.width/2, y:200)
        myButton.addTarget(self, action: #selector(self.onClickMyButton(sender:)), for: .touchUpInside)

        view.addSubview(boxView)
        view.addSubview(myButton)
        
        
        // for vibration
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }

        self.setupAVCapture()
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        var events = [CHHapticEvent]()

        for i in stride(from: 0, to: 1, by: 0.1) {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(1 - i))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(1 - i))
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: i)
            events.append(event)
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play pattern: \(error.localizedDescription).")
        }
    }
    
//    // The engine stopped; print out why
//    engine?.stoppedHandler = { reason in
//        print("The engine stopped: \(reason)")
//    }
//
//    // If something goes wrong, attempt to restart the engine immediately
//    engine?.resetHandler = { [weak self] in
//        print("The engine reset")
//
//        do {
//            try self?.engine?.start()
//        } catch {
//            print("Failed to restart the engine: \(error)")
//        }
//    }
    

    override var shouldAutorotate: Bool {
        if (UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft ||
        UIDevice.current.orientation == UIDeviceOrientation.landscapeRight ||
        UIDevice.current.orientation == UIDeviceOrientation.unknown) {
            return false
        }
        else {
            return true
        }
    }

    @objc func onClickMyButton(sender: UIButton){
        print("button pressed")
    }
}


// AVCaptureVideoDataOutputSampleBufferDelegate protocol and related methods
extension ViewController:  AVCaptureVideoDataOutputSampleBufferDelegate{
     func setupAVCapture(){
        session.sessionPreset = AVCaptureSession.Preset.vga640x480
        guard let device = AVCaptureDevice
        .default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                 for: .video,
                 position: AVCaptureDevice.Position.back) else {
                            return
        }
        captureDevice = device
        beginSession()
    }

    func beginSession(){
        var deviceInput: AVCaptureDeviceInput!

        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            guard deviceInput != nil else {
                print("error: cant get deviceInput")
                return
            }

            if self.session.canAddInput(deviceInput){
                self.session.addInput(deviceInput)
            }

            videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.alwaysDiscardsLateVideoFrames=true
            videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
            videoDataOutput.setSampleBufferDelegate(self, queue:self.videoDataOutputQueue)

            if session.canAddOutput(self.videoDataOutput){
                session.addOutput(self.videoDataOutput)
            }

            videoDataOutput.connection(with: .video)?.isEnabled = true

            previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect

            let rootLayer :CALayer = self.previewView.layer
            rootLayer.masksToBounds=true
            previewLayer.frame = rootLayer.bounds
            rootLayer.addSublayer(self.previewLayer)
            session.startRunning()
        } catch let error as NSError {
            deviceInput = nil
            print("error: \(error.localizedDescription)")
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // do stuff here
    }

    // clean up AVCapture
    func stopCamera(){
        session.stopRunning()
    }

}
