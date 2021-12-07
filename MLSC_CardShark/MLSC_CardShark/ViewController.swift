//
//  ViewController.swift
//  MLSC_CardShark
//
//  Created by Eric Miao on 12/4/21.
//

import UIKit
import CoreHaptics

// Reference for camera feed and frames Extraction:
//   - stackoverflow.com/questions/28487146/how-to-add-live-camera-preview-to-uiview
//   - medium.com/ios-os-x-development/ios-camera-frames-extraction-d2c0f80ed05a
// Reference for using CoreHaptics: www.hackingwithswift.com/example-code/core-haptics/how-to-play-custom-vibrations-using-core-haptics

class ViewController: UIViewController, FrameExtractorDelegate {
    var engine: CHHapticEngine? // initialize haptic engine
    var frameExtractor: FrameExtractor! // initialize FrameExtractor Delegate
    var gameStarted = false // current game status
    
    @IBOutlet weak var gameButton: UIButton!
    @IBOutlet weak var flipCameraButton: UIButton!
    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var testButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        flipCameraButton.isEnabled = true
        
        checkCHHapticEngine();
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
    }
    
    
    // make sure haptics are supported on the current device using
    func checkCHHapticEngine(){
        // for vibration
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }
    }
    
    
    @IBAction func testButtonPressed(_ sender: Any) {
        vibrate(repeatCount: 5)
    }
    
    // vibrate based on time
    func vibrate(repeatCount: Int){
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        var events = [CHHapticEvent]()
        for i in stride(from: 0, to: repeatCount, by: 1) {
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [], relativeTime: Double(i)/2, duration: 0.4)
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
    

    
    func captured(image: UIImage) {
        DispatchQueue.main.async { // Does not work without this dispatch
            self.cameraView.image = image
        }
        //         let convertedImage = convertImageToBase64String(img: image);
        //         print(convertedImage)
    }
    
    
    
    @IBAction func gameButtonPressed(_ sender: UIButton) {
        gameStarted = !gameStarted
        if gameStarted{
            gameButton.setTitle("End", for: .normal)
            frameExtractor.start();
        }else{
            gameButton.setTitle("Start", for: .normal)
            frameExtractor.end();
            cameraView.image = nil;
        }
        
    }
    
    
    @IBAction func flipCameraButtonPressed(_ sender: UIButton) {
        frameExtractor.flipCamera()
    }
    
    
    // Encoding: UIImage to String
    // Source: https://stackoverflow.com/questions/11251340/convert-between-uiimage-and-base64-string
    func convertImageToBase64String (img: UIImage) -> String {
        return UIImageJPEGRepresentation(img, 1)?.base64EncodedString() ?? ""
    }
    
    
    
}

