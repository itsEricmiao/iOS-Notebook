//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Code adapted by Joshua Sylvester, Canon Ellis, and Eric Miao
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
    var flashOn = false;
    var readyForPPG = false;
    
    //MARK: Outlets in view
    // Declare Labels
    @IBOutlet weak var stageLabel: UILabel! // actually this label will show the number of user detected
    @IBOutlet weak var numFacesDetectedLabel: UILabel!
    @IBOutlet weak var smileLabel: UILabel! // show if the user detected is smile or not
    @IBOutlet weak var blinkLabel: UILabel! // show if the user detected is blinking or not and if blinking, which eye
    @IBOutlet weak var heartRateLabel: UILabel!
    @IBOutlet weak var viewDescriptionLabel: UILabel!
    @IBOutlet weak var distortionRadiusLabel: UILabel!
    
    // Declare Buttons
    @IBOutlet weak var getPPGButton: UIButton!
    @IBOutlet weak var toggleCameraButton: UIButton!
    
    // Declare Sliders
    @IBOutlet weak var radiusSlider: UISlider!
    
    // Declare Chart View
    @IBOutlet weak var chartView: UIView!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = nil
        // setup the screen height and width
        self.height = view.frame.height
        self.width = view.frame.width
        
        // Setup Screen Stage
        self.bridge.processType = 0
        self.stageLabel.text = "Stage: \(self.bridge.processType)"
        
        // Setup initial button and label states
        self.getPPGButton.isEnabled = false
        self.getPPGButton.backgroundColor = UIColor.gray
        self.toggleCameraButton.backgroundColor = UIColor.blue
        self.heartRateLabel.isHidden = true
        
        // LARSON CODE:
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
        
        // Start the chart view off as hidden
        self.chartView.isHidden = true
    }
    
    //MARK: Process image output
    // In retrospect we should have separated these into 2 different view controllers but alas we didn't. So processType 1 is for moduleA and processType2 is for moduleB
    // For moduleA (the body of the if we process the faces)
    // For moduleB (the body of the else, we handle the heart rate
    func processImageSwift(inputImage:CIImage) -> CIImage{
        if(self.bridge.processType != 1){
            // detect faces
            let f = getFaces(img: inputImage)
            DispatchQueue.main.async {
                self.numFacesDetectedLabel.text = "# Face(s) Detected: " + String(f.count)
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
        } else {
            var retImage = inputImage

            //HINT: you can also send in the bounds of the face to ONLY process the face in OpenCV
            // or any bounds to only process a certain bounding region in OpenCV
            self.bridge.setTransforms(self.videoManager.transform)
            self.bridge.setImage(retImage,
                                 withBounds: retImage.extent, // the first face bounds
                                 andContext: self.videoManager.getCIContext())
            
            // If the getPPG button has been clicked
            if(readyForPPG) {
                if(!flashOn) { // if the ppg is not already running
                    self.videoManager.turnOnFlashwithLevel(0.3)
                    flashOn = true;
                    self.bridge.arrIdx = 0;
                    DispatchQueue.main.async {
                        self.heartRateLabel.text = "Heart Rate: Pending"
                        self.chartView.isHidden = true
                        self.chartView.layer.sublayers = nil
                    }
                }
                
                var processingDone = self.bridge.processFinger() // The call for heart rate processing
                
                // processingDone is -1.0 by default so as long as it's -1 we should keep running
                // unless we get a -2.0 back which means the heart rate was not detected and you should try again
                // If we get any other value then that is the bpm
                if(processingDone != -1.0) {
                    self.videoManager.turnOffFlash()
                    flashOn = false
                    readyForPPG = false;
                    DispatchQueue.main.async {
                        self.getPPGButton.isEnabled = true
                        self.getPPGButton.backgroundColor = UIColor.blue
                    }
                    if(processingDone == -2.0) {
                        DispatchQueue.main.async {
                            self.heartRateLabel.text = "Heart Rate Not Detected. Try Again"
                        }
                    }
                    else {
                        DispatchQueue.main.async {
                            self.heartRateLabel.text = "Heart Rate: " + String(format: "%.2f", processingDone) + " bpm"
                        }
                        
                        // Update a view on the UI by adding points to it representing datapoints
                        // We realize this is egregiously bad code, but we couldn't figure out any other way to do it in a short amount of time
                        DispatchQueue.main.async {
                            self.chartView.isHidden = false
                            
                            for i in 150..<600{
                                
                                let xCoord = i / 2
                                var yCoord = self.bridge.getPPGData(Int32(i))
                                let radius = 2

                                let dotPath = UIBezierPath(ovalIn: CGRect(x: xCoord, y: Int(yCoord), width: radius, height: radius))

                                let layer = CAShapeLayer()
                                layer.path = dotPath.cgPath
                                layer.strokeColor = UIColor.blue.cgColor

                                self.chartView.layer.addSublayer(layer)
                            }
                        }
                    }
                }
            }
            retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)

            return retImage
        }
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
            features.append(f.leftEyePosition)
        }
        if f.hasRightEyePosition{
            features.append(f.rightEyePosition)
        }
        if f.hasMouthPosition{
            // check for smile
            if f.hasSmile{
                features.append(f.mouthPosition)
            }else{
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
            }
            // if only left eye is closed
            //!blinking && !rightEyeClosed &&
            else if rightEyeClosed{
                DispatchQueue.main.async {
                    self.blinkLabel.text = "Detected Left eye is blinking!"
                  }
            }
            
            // if only right eye is closed
            //!blinking && !leftEyeClosed &&
            else if leftEyeClosed{
                DispatchQueue.main.async {
                    self.blinkLabel.text = "Detected Right eye is blinking!"
                  }
            }
            
            // if both eyes are open
            else{
                DispatchQueue.main.async {
                    self.blinkLabel.text = "No eye is blinking!"
                  }
            }
            
            // if user is smiling
            if isSmiling{
                DispatchQueue.main.async {
                    self.smileLabel.text = "Detected Smiling"
                }
            }
            // if user is NOT smiling
            else{
                DispatchQueue.main.async {
                    self.smileLabel.text = "Detected NOT Smiling"
                }
            }
        }
        
    }
    
    
    // change the type of processing done in OpenCV
    @IBAction func swipeRecognized(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case .left:
            if(self.bridge.processType + 1 != 2) {
                self.bridge.processType += 1
            } else {
                return
            }
        case .right:
            if(self.bridge.processType - 1 != -1) {
                self.bridge.processType -= 1
            } else {
                return
            }
        default:
            return
            break
        }
        
        // For Moving to Module A screen
        // The manual setting of isEnabled and hidden here is probably bad code, we should have separeted these into another vc but we realized too late.
        if(self.bridge.processType == 1) {
            DispatchQueue.main.async {
                // Disable Chart until data is gotten
                self.chartView.isHidden = true
                
                // Set Camera to Back for PPG reading
                self.videoManager.ifCameraFrontSetToBack()
                
                // Toggle Buttons
                self.getPPGButton.isEnabled = true
                self.getPPGButton.backgroundColor = UIColor.blue
                self.toggleCameraButton.isEnabled = false
                self.toggleCameraButton.backgroundColor = UIColor.gray
                
                // Toggle Labels
                self.smileLabel.isHidden = true
                self.blinkLabel.isHidden = true
                self.numFacesDetectedLabel.isHidden = true
                self.heartRateLabel.isHidden = false
                self.distortionRadiusLabel.isHidden = true
                self.heartRateLabel.text = "Heart Rate: Pending"
                self.viewDescriptionLabel.text = "Module B (Swipe Right for Module A)"
                
                // Toggle Slider
                self.radiusSlider.isHidden = true
                
            }
        // For Moving to Module B screen
        } else {
            DispatchQueue.main.async {
                // Disable Chart
                self.chartView.isHidden = true
                
                // Set Camera to Front
                self.videoManager.ifCameraBackSetToFront()
                
                // Toggle Buttons
                self.getPPGButton.isEnabled = false
                self.getPPGButton.backgroundColor = UIColor.gray
                self.toggleCameraButton.isEnabled = true
                self.toggleCameraButton.backgroundColor = UIColor.blue
                
                // Toggle Labels
                self.numFacesDetectedLabel.isHidden = false
                self.smileLabel.isHidden = false
                self.blinkLabel.isHidden = false
                self.heartRateLabel.isHidden = true
                self.distortionRadiusLabel.isHidden = false
                self.viewDescriptionLabel.text = "Module A (Swipe Right for Module B)"
                
                // Toggle Slider
                self.radiusSlider.isHidden = false
                
            }
        }
        
        DispatchQueue.main.async{
            self.stageLabel.text = "Stage: \(self.bridge.processType)"
        }
    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func switchCamera(_ sender: AnyObject) {
        self.videoManager.toggleCameraPosition()
    }
    
    
    @IBAction func radiusSliderOnChange(_ sender: UISlider) {
        self.radius = sender.value
    }
    
    @IBAction func getPPG(_ sender: Any) {
        DispatchQueue.main.async {
            self.getPPGButton.isEnabled = false
            self.getPPGButton.backgroundColor = UIColor.gray
        }
        self.readyForPPG = true;
        
    }
}

