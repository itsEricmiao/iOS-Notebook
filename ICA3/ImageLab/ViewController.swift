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
    var time: Double = Date().timeIntervalSinceReferenceDate * 1000;
    var flashOn = false;
    
    var height :CGFloat = 0
    var width : CGFloat = 0
    
    //MARK: Outlets in view
    @IBOutlet weak var flashSlider: UISlider!
    @IBOutlet weak var stageLabel: UILabel!
    
    @IBOutlet weak var toggleCameraButton: UIButton!
    @IBOutlet weak var toggleFlashButton: UIButton!
    
    @IBOutlet weak var drawView: UIView!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = nil
        self.drawView.backgroundColor = UIColor(white: 1, alpha: 0.1)
        self.height = self.view.frame.height
        self.width = self.view.frame.width
        // setup the OpenCV bridge nose detector, from file
//        self.bridge.loadHaarCascade(withFilename: "nose")
        self.videoManager = VideoAnalgesic(mainView: self.view)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these properties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow,CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
//        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageSwift)
        
        self.bridge.setTransforms(self.videoManager.transform)
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImages)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    }
    
    func processImages(inputImage:CIImage)->CIImage{
        var retImage = inputImage
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let faces = faceDetector?.features(in: retImage) as! [CIFaceFeature]
        self.drawFaces(faceImage: inputImage, faces:faces)
//        let facialFeatures = getFacialFeatures(faces: faces)
//        let result = applyFiltersToFaces(inputImage: inputImage, facialFeatures: facialFeatures)

        DispatchQueue.main.async {
            self.stageLabel.text = "Face Detected: " + String(faces.count)
          }
        print("Number of faces: \(faces.count)")
        return retImage
    }
    
    func drawFaces(faceImage: CIImage, faces: [CIFaceFeature]){
        
        let transformScale = CGAffineTransform(scaleX: 1, y: -1)
        let transform = transformScale.translatedBy(x: 0, y: -faceImage.extent.height)
            
        for face in faces{
            var faceBounds = face.bounds.applying(transform)
            DispatchQueue.main.async {
                let imageViewSize = self.drawView.bounds.size
                let scale = min(imageViewSize.width / faceImage.extent.width,
                                        imageViewSize.height / faceImage.extent.height)
                        
                let dx = (imageViewSize.width - faceImage.extent.width * scale) / 2
                let dy = (imageViewSize.height - faceImage.extent.height * scale) / 2
                        
                faceBounds.applying(CGAffineTransform(scaleX: scale, y: scale))
                faceBounds.origin.x += dx
                faceBounds.origin.y += dy
                let box = UIView(frame: faceBounds)
                box.layer.borderColor = UIColor.red.cgColor
                box.layer.borderWidth = 2
                box.backgroundColor = UIColor.clear
                self.drawView.addSubview(box)
            }
        }
    }
    
    // Reference: www.appcoda.com/face-detection-core-image/
    func getFacialFeatures(faces:[CIFaceFeature])-> [(String, CGPoint)] {
        var facialFeatures:[(featureType: String, location: CGPoint)] = []
        for f in faces{
            // get the left eye, right eye, and mouth
            if f.hasLeftEyePosition{
                print("found left eye: ",  f.leftEyePosition)
                facialFeatures.append((featureType: "eye", location: f.leftEyePosition))
            }
            if f.hasRightEyePosition{
                print("found right eye:", f.rightEyePosition)
                facialFeatures.append((featureType: "eye", location: f.rightEyePosition))
            }
            if f.hasMouthPosition{
                // check for smile
                if f.hasSmile{
                    print("Smile  - Mouth:", f.mouthPosition)
                    facialFeatures.append((featureType: "mouth_smile", location: f.mouthPosition))
                }else{
                    print("NOT Smile - Mouth: ", f.mouthPosition)
                    facialFeatures.append((featureType: "mouth_no_smile", location: f.mouthPosition))
                }
            }
        }
        
        return facialFeatures
    }
    
    func applyFiltersToFaces(inputImage:CIImage, facialFeatures:[(String, CGPoint)])->CIImage{
        var retImage = inputImage
        // Scaling for display
        let scaleHeight = retImage.extent.height/height
        let scaleWidth = retImage.extent.width/width
    
        var mouthFilters : [CIFilter]! = nil
        mouthFilters = []
        
        let sepiaFilter = CIFilter(name:"CISepiaTone")
        sepiaFilter?.setValue(retImage, forKey: kCIInputImageKey)
        sepiaFilter?.setValue(0.5, forKey: kCIInputIntensityKey)
        mouthFilters.append(sepiaFilter!)
        
        
        for (featureType, filterCenter) in facialFeatures {
            if featureType == "mouth_smile" || featureType == "mouth_no_smile"{
                for filt in mouthFilters{
                    retImage = filt.outputImage!
                    // Set the image for opencv
                    self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
                    // Scale x,y location so it is easier to display smiling/not smiling
                    let xLocation = Int(filterCenter.y * scaleHeight)
                    let yLocation = Int(filterCenter.x * scaleWidth)
                    retImage = self.bridge.getImage()
                }
            }
        }
        return retImage
    }

    
    
    //MARK: Process image output
    func processImageSwift(inputImage:CIImage) -> CIImage{
        var retImage = inputImage
        //HINT: you can also send in the bounds of the face to ONLY process the face in OpenCV
        // or any bounds to only process a certain bounding region in OpenCV
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: retImage.extent, // the first face bounds
                             andContext: self.videoManager.getCIContext())
        var isFinger = self.bridge.processFinger()
        if(isFinger) {
            DispatchQueue.main.async {
                self.toggleCameraButton.isEnabled = false
                self.toggleFlashButton.isEnabled = false
            }
            if( Date().timeIntervalSinceReferenceDate * 1000 > time + 1000 )  {
                if (!flashOn) {
                    self.videoManager.turnOnFlashwithLevel(0.2)
                    flashOn = true
                }
                time = Date().timeIntervalSinceReferenceDate * 1000;
            }
        } else {
            DispatchQueue.main.async {
                self.toggleCameraButton.isEnabled = true
                self.toggleFlashButton.isEnabled = true
            }
            if( Date().timeIntervalSinceReferenceDate * 1000 > time + 1000 ) {
                if (flashOn) {
                    self.videoManager.turnOffFlash()
                    flashOn = false
                }
                time = Date().timeIntervalSinceReferenceDate * 1000;
            }
        }
        retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)

        return retImage
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
        stageLabel.text = "Stage: \(self.bridge.processType)"
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

