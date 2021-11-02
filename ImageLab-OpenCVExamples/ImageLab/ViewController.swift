//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController   {
    
    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    var height: CGFloat = 0.0
    var width: CGFloat = 0.0
    var radius: Float = 0.0
    
    @IBOutlet weak var radiusSlider: UISlider!
    //MARK: Outlets in view
    @IBOutlet weak var smileLabel: UILabel! // show if the user detected is smile or not
    @IBOutlet weak var blinkLabel: UILabel! // show if the user detected is blinking or not and if blinking, which eye
    
    @IBOutlet weak var flashSlider: UISlider!
    @IBOutlet weak var stageLabel: UILabel! // actually this label will show the number of user detected
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = nil
        // setup the screen height and width
        self.height = view.frame.height
        self.width = view.frame.width
        
        // setup the OpenCV bridge nose detector, from file
        self.bridge.loadHaarCascade(withFilename: "nose")
        
        self.videoManager = VideoAnalgesic(mainView: self.view)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.front)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these properties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow,CIDetectorTracking:true] as [String : Any]
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                   context: self.videoManager.getCIContext(), // perform on the GPU is possible
                                   options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageSwift)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    }
    
    //MARK: Process image output
    func processImageSwift(inputImage:CIImage) -> CIImage{
        // detect faces
        let f = getFaces(img: inputImage)
        DispatchQueue.main.async {
            self.stageLabel.text = "Face Detected: " + String(f.count)
        }
        
        // if no faces, just update the label and return original image
        if f.count == 0 {
            DispatchQueue.main.async {
                self.blinkLabel.text = "No face is in the frame."
                self.smileLabel.text = "No face is in the frame."
            }
            return inputImage
            
        }
        
        // if only one face detected, shows the smile and blink info
        if f.count == 1 {
            detectSmileAndBlink(faceImage: inputImage)
        
        // if multiple faces detected, disable the blink and smile detection
        }else if f.count > 1 {
            DispatchQueue.main.async {
                self.blinkLabel.text = "Blink Detection only works when one face in the frame."
                self.smileLabel.text = "Smile Detection only works when one face in the frame."
            }
        }
        
        // make a copy of the original image
        var retImage = inputImage
        
        self.bridge.setTransforms(self.videoManager.transform)
        for face in f{
            let face_features = getFeature(f: face)
            for filterCenter in face_features{
                print("Center:", filterCenter)
                print("Face bounds: ", face.bounds)
                //Reference: www.developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html#//apple_ref/doc/filter/ci
                
                // Scale the filter radius based on the face to UIView frame proportion so the filter can work on small faces too
                let scale = face.bounds.height/(self.height)
                let filt = CIFilter(name:"CIBumpDistortion")!
                filt.setValue(100 * scale * CGFloat(self.radius), forKey: "inputRadius")
                filt.setValue(retImage, forKey: kCIInputImageKey)
                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                retImage = filt.outputImage!
            }
            
            self.bridge.setImage(retImage,
                                 withBounds: face.bounds,
                                 andContext: self.videoManager.getCIContext())


            self.bridge.processImage()
            retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
        }
        
        return retImage
    }
    
    
    //MARK: Setup Face Detection
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
    }
    
    
    // Reference: www.appcoda.com/face-detection-core-image/
    // Provide a face, find the features on it
    func getFeature(f: CIFaceFeature) ->[CGPoint] {
        var features:[CGPoint] = []
        if f.hasLeftEyePosition{
            print("found left eye: ",  f.leftEyePosition)
            features.append(f.leftEyePosition)
        }
        if f.hasRightEyePosition{
            print("found right eye:", f.rightEyePosition)
            features.append(f.rightEyePosition)
        }
        if f.hasMouthPosition{
            // check for smile
            if f.hasSmile{
                print("Smile  - Mouth:", f.mouthPosition)
                features.append(f.mouthPosition)
            }else{
                print("NOT Smile - Mouth: ", f.mouthPosition)
                features.append(f.mouthPosition)
            }
        }
        return features
    }
    
    
    
    // function for detecting if the face detected is smiling and/or blinking
    // Reference: www.developer.apple.com/forums/thread/131135
    func detectSmileAndBlink(faceImage: CIImage){
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        let faces = faceDetector?.features(in: faceImage, options: [CIDetectorSmile:true, CIDetectorEyeBlink: true])
        // Since I call this function only when one face is in the frame, so the lenth of faces will always be 1
        for face in faces as! [CIFaceFeature] {
            // using the Apple's API to find blinking and smiling info
            let leftEyeClosed = face.leftEyeClosed
            let rightEyeClosed = face.rightEyeClosed
            let blinking = face.rightEyeClosed && face.leftEyeClosed
            let isSmiling = face.hasSmile
            print(blinking, leftEyeClosed, rightEyeClosed)
            // if both eyes are closed
            if leftEyeClosed && rightEyeClosed{
                DispatchQueue.main.async {
                    self.blinkLabel.text = "Detected BOTH eyes are blinking!"
                  }
                print("Detected BOTH eyes are blinking")
            }
            
            // if only left eye is closed
            //!blinking && !rightEyeClosed &&
            else if rightEyeClosed{
                DispatchQueue.main.async {
                    self.blinkLabel.text = "Detected Left eye is blinking!"
                  }
                print("Detected left eye blinking")
            }
            
            // if only right eye is closed
            //!blinking && !leftEyeClosed &&
            else if leftEyeClosed{
                DispatchQueue.main.async {
                    self.blinkLabel.text = "Detected Right eye is blinking!"
                  }
                print("Detected right eye blinking")
            }
            
            // if both eyes are open
            else{
                DispatchQueue.main.async {
                    self.blinkLabel.text = "No eye is blinking!"
                  }
                print("No eye is blinking!")
            }
            
            // if user is smiling
            if isSmiling{
                DispatchQueue.main.async {
                    self.smileLabel.text = "Detected Smiling"
                }
                print("Detected Smiling")
            }
            // if user is NOT smiling
            else{
                DispatchQueue.main.async {
                    self.smileLabel.text = "Detected NOT Smiling"
                }
                print("Detected NOT Smiling")
            }
        }
        
    }
    
    
    // change the type of processing done in OpenCV
    @IBAction func swipeRecognized(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case .left:
            self.bridge.processType += 1
        case .right:
            self.bridge.processType -= 1
        default:
            break
            
        }
    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        if(self.videoManager.toggleFlash()){
            self.flashSlider.value = 1.0
        }
        else{
            self.flashSlider.value = 0.0
        }
    }
    
    @IBAction func switchCamera(_ sender: AnyObject) {
        self.videoManager.toggleCameraPosition()
    }
    
    
    @IBAction func radiusSliderOnChange(_ sender: UISlider) {
        self.radius = sender.value
    }
    
    @IBAction func setFlashLevel(_ sender: UISlider) {
        if(sender.value>0.0){
            let val = self.videoManager.turnOnFlashwithLevel(sender.value)
            if val {
                print("Flash return, no errors.")
            }
        }
        else if(sender.value==0.0){
            self.videoManager.turnOffFlash()
        }
    }
}

