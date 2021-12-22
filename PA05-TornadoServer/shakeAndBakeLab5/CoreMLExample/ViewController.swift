//
//  ViewController.swift
//  shakeAndBakeLab5
//
//  Code Adapted from Eric Larson's ICA4
//  Updated code created by Joshua Sylvester, Eric Miao, and Canon Ellis
//

import UIKit
import CoreML
import Vision
import CoreImage

class ViewController: UIViewController, UINavigationControllerDelegate, URLSessionDelegate, UIPickerViewDelegate, UIPickerViewDataSource{
    
    //MARK: UI View Elements
    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var classifierLabel: UILabel!
    @IBOutlet weak var numberPicker: UIPickerView!
    @IBOutlet weak var trainButton: UIButton!
    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var dsidStepper: UIStepper!
    @IBOutlet weak var predictionLabel: UILabel!
    @IBOutlet weak var accLabel: UILabel!
    
    @IBOutlet weak var maxIterationsLabel: UILabel!
    @IBOutlet weak var maxIterationStepper: UIStepper!
    
    @IBOutlet weak var addDataButton: UIButton!
    @IBOutlet weak var predictButton: UIButton!
    @IBOutlet weak var theSwitch: UISwitch!
    
    // MARK: Load ML Properties
    lazy var MyModel:mymodel = {
        do{
            let config = MLModelConfiguration()
            return try mymodel(configuration: config)
        }catch{
            print(error)
            fatalError("Could not load local ML Model")
        }
    }()
    
    lazy var model: VNCoreMLModel? = {
        guard let tmpModel = try? VNCoreMLModel(for: MyModel.model) else {
            return nil
        }
       return tmpModel
    }()
    
    
    // MARK: Class Properties
    let SERVER_URL = "http://169.254.236.36:8000"
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
    }()
    let operationQueue = OperationQueue()

    let animation = CATransition()
    var needProcessing = true
    
    // MARK: Variables for UI
    var numberOptions: [String] = []
    var chosenModel: String = "best"
    
    var dsid:Int = 0 {
        didSet{
            dsidStepper.value = Double(self.dsid)
            DispatchQueue.main.async{
                // update label when set
                self.dsidLabel.layer.add(self.animation, forKey: nil)
                self.dsidLabel.text = "Current DSID: \(self.dsid)"
            }
        }
    }
    
    var maxIterations:Int = 10 {
        didSet{
            maxIterationStepper.value = Double(self.maxIterations)
            DispatchQueue.main.async{
                // update label when set
                self.maxIterationsLabel.layer.add(self.animation, forKey: nil)
                self.maxIterationsLabel.text = "Max Iterations: \(self.maxIterations)"
            }
        }
    }
    
    var useLocalModel = true
    var currentImage: UIImage? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        numberOptions = ["TwoClubs", "NineClubs", "KingClubs"]
        
        self.numberPicker.delegate = self
        numberPicker.dataSource = self
        
        self.dsid = 148
        self.maxIterations = 10
        
        self.addDataButton.isEnabled = false
        self.predictButton.isEnabled = false
        self.maxIterationsLabel.isHidden = true
        self.maxIterationStepper.isHidden = true
        self.accLabel.isHidden = true
        self.predictionLabel.isHidden = true

    }
    
    // MARK: Number Picker Code
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1;
    }
    
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return numberOptions.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return numberOptions[row]
    }

    // MARK: Segmented Control
    @IBAction func modelSelectChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex{
        case 0:
            print("Currently using best")
            self.chosenModel = "best"
            DispatchQueue.main.async{
                self.maxIterationsLabel.isHidden = true
                self.maxIterationStepper.isHidden = true
            }
        case 1:
            print("Currently using Boosted Trees")
            self.chosenModel = "BTC"
            DispatchQueue.main.async{
                self.maxIterationsLabel.isHidden = false
                self.maxIterationStepper.isHidden = false
            }
        case 2:
            print("Currently using Logistic Classifier")
            self.chosenModel = "LC"
            DispatchQueue.main.async{
                self.maxIterationsLabel.isHidden = false
                self.maxIterationStepper.isHidden = false
            }
        default:
            return
        }
        // update UI if we changed and an image exists
        if let image = self.mainImageView.image {
            classifyImage(image: image)
        }
    }
    
    @IBAction func switchChange(_ sender: Any) {
        useLocalModel = !useLocalModel
    }
    
    
    // MARK: Button Actions
    @IBAction func addDataButtonOnClicked(_ sender: UIButton) {
        // call the train functions
        let serializedImageStr = self.convertImageToBase64String(img: self.mainImageView.image!)
        let numberVal = numberOptions[self.numberPicker.selectedRow(inComponent: 0)]
        self.sendFeatures(serializedImageStr, withLabel: numberVal)
    }
    
    @IBAction func train(_ sender: Any) {
        makeModel()
    }
    
    @IBAction func predict(_ sender: Any) {
        // call the train functions
        let serializedImageStr = self.convertImageToBase64String(img: self.mainImageView.image!)
        // TODO: SETUP WHICH ONE TO USE
        if (useLocalModel) {
            getPredictionFromLocalModel()
        } else {
            getPrediction(serializedImageStr)
        }
    }
    
    //MARK: Camera View Presentation
    @IBAction func takePicture(_ sender: UIButton) {
        
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        }
        
        let cameraPicker = UIImagePickerController()
        cameraPicker.delegate = (self as UIImagePickerControllerDelegate & UINavigationControllerDelegate)
        cameraPicker.sourceType = .camera
        cameraPicker.allowsEditing = false
        present(cameraPicker, animated: true)
    }
    
    // Encoding: UIImage to String
    // Source: https://stackoverflow.com/questions/11251340/convert-between-uiimage-and-base64-string
    func convertImageToBase64String (img: UIImage) -> String {
        return UIImageJPEGRepresentation(img, 1)?.base64EncodedString() ?? ""
    }

    
    // MARK: Model Interaction
    // Function for adding training data point
    func sendFeatures(_ imageStr: String, withLabel label:String){
        let baseURL = "\(SERVER_URL)/AddDataPoint"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature": imageStr,
                                       "label":label,
                                       "dsid":self.dsid]
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        request.httpMethod = "POST"
        request.httpBody = requestBody
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    if let res = response{
                        print("Response:\n",res)
                        self.showErrorAlert(title: "Unknown Error", message: "An Unknown Error Occurred. Try Restarting the App or Changing DSIDs")
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    print(jsonDictionary["label"]!)
                }

        })
        postTask.resume() // start the task
    }
    
    // This function calls the backend route which creates, trains, and saves a model
    func makeModel() {
        // Setup Post Request
        let baseURL = "\(SERVER_URL)/UpdateChosenModel"
        let postUrl = URL(string: baseURL)
        var request: URLRequest = URLRequest(url: postUrl!)
        let jsonUpload:NSDictionary = ["dsid":self.dsid, "modelType": self.chosenModel, "maxIterations": self.maxIterations]
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request, completionHandler:{(data, response, error) in
            // Handle an unforseen error
            if(error != nil){
                if let res = response{
                    self.showErrorAlert(title: "Unknown Error", message: "An unknown error occurred")
                    print("Response:\n",res)
                }
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    /// Handle 200 Success
                    if httpResponse.statusCode == 200 {
                        let jsonDictionary = self.convertDataToDictionary(with: data)
                        if let resubAcc: String = jsonDictionary["resubAccuracy"] as? String {
                            print("Resubstitution Accuracy is", resubAcc)
                            DispatchQueue.main.async{
                                self.accLabel.isHidden = false
                                self.accLabel.text = "Train Acc: " +  resubAcc
                            }
                        } else {
                            self.showErrorAlert(title: "Unknown Error", message: "An unknown error occurred")
                        }
                    }
                    /// Handle 404 Error
                    else if httpResponse.statusCode == 404 {
                        self.showErrorAlert(title: "Data Doesn't Exist", message: "You need to upload data for this model before you can train it.")
                    /// Handle Unknown Error
                    } else {
                        self.showErrorAlert(title: "Unknown Error", message: "An unknown error occurred")
                    }
                 }
            }
        })
        dataTask.resume() // start the task
    }

    // Get prediction from server
    func getPrediction(_ imageStr: String){
        // Setup the Post Request
        let baseURL = "\(SERVER_URL)/PredictOneChosenModel"
        let postUrl = URL(string: "\(baseURL)")
        var request = URLRequest(url: postUrl!)
        let jsonUpload:NSDictionary = ["feature":imageStr, "dsid":self.dsid, "modelType": self.chosenModel]
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request, completionHandler:{
            (data, response, error) in
                if(error != nil){
                    if let res = response {
                        self.showErrorAlert(title: "Unknown Error", message: "An unknown error occurred")
                        print("Response:\n",res)
                    }
                } else {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            let jsonDictionary = self.convertDataToDictionary(with: data)
                            let labelResponse = jsonDictionary["prediction"]!
                            self.displayLabelResponse(labelResponse as! String)
                        }
                        else if httpResponse.statusCode == 404 {
                            self.showErrorAlert(title: "Model Doesn't Exist", message: "The model you are trying to use doesn't exist, you need to train it first")
                        } else {
                            self.showErrorAlert(title: "Unknown Error", message: "An unknown error occurred")
                        }
                    }
                }
        })
        postTask.resume() // start the task
    }
    
    // Function for getting prediction from local model
    func getPredictionFromLocalModel(){
        // generate request for vision and ML model
        let processedImageData = preprocess(image: self.currentImage!)
        let model = mymodel()
        guard let output = try? model.prediction(sequence:processedImageData!)else {
            print("Unexpected runtime error.")
            fatalError("Unexpected runtime error.")
        }
        self.displayLabelResponse(output.target as! String)
        
    }
    
    // This function processes an image for sending to the model stored on phone
    // Referenced from: https://githubmemory.com/repo/hollance/CoreMLHelpers/issues/5
    func preprocess(image: UIImage) -> MLMultiArray? {
        let size = CGSize(width: 235, height: 235)
        guard let pixels = image.resize(to: size).pixelData()?.map({ (Int($0))}) else {
            return nil
        }

        // Init return type as MLMultiArray
        guard let array_2d = try? MLMultiArray(shape: [1, 235, 235], dataType: .double) else {
            return nil
        }
        
        // Get RGB vals from the pixels
        let r = pixels.enumerated().filter { $0.offset % 4 == 0 }.map { $0.element }
        let g = pixels.enumerated().filter { $0.offset % 4 == 1 }.map { $0.element }
        let b = pixels.enumerated().filter { $0.offset % 4 == 2 }.map { $0.element }
 
        // Average the RGB Values to do a rough grayscale
        for (index, element) in r.enumerated() {
            array_2d[index] = NSNumber(value: Int((r[index] + g[index] + b[index])/3))
        }
        return array_2d
    }
    
    // MARK: Error Handling Functions
    func showErrorAlert(title: String, message: String) {
        DispatchQueue.main.async{
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: {_ in
                print("alert dismissed")
            }))
            self.view?.window?.rootViewController?.present(alert, animated: true)
        }
    }
    
    func displayLabelResponse(_ response:String){
        DispatchQueue.main.async{
            self.predictionLabel.isHidden = false
            self.predictionLabel.text = "Prediction: " + response
        }
    }
    
    
    // MARK: DSID Stepper
    @IBAction func onStepperChange(_ sender: UIStepper) {
        dsid = Int(sender.value)
    }
    
    
    @IBAction func onMaxIterationChange(_ sender: UIStepper){
        maxIterations = Int(sender.value)
    }
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
                try JSONSerialization.jsonObject(with: data!,
                                              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            return jsonDictionary
            
        } catch {
            
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                            print("printing JSON received as string: "+strData)
            }else{
                print("json error: \(error.localizedDescription)")
            }
            return NSDictionary() // just return empty
        }
    }
    
    
}

extension ViewController: UIImagePickerControllerDelegate {
    
    //MARK: Camera View Callbacks
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true)
        guard let image = info["UIImagePickerControllerOriginalImage"] as? UIImage else {
            return
        }
        
        // perform this on a background queue
        DispatchQueue.global().async {
            self.needProcessing = true
            let newImage = self.classifyImage(image: image)
            
            // use update on new queue
            DispatchQueue.main.async{
                self.mainImageView.image = newImage
                self.addDataButton.isEnabled = true
                self.predictButton.isEnabled = true
                self.predictionLabel.isHidden = true
            }
        }
        
    }
    
    //MARK: Image Modification Methods
    // use vision API to classify image
    func classifyImage(image:UIImage) -> (UIImage){
//        // Filters: -crop image so it isn't squashed
//        //          -increase contrast
//        //          -add some blurring/noise filters
//
        // got this from here: http://wiki.hawkguide.com/wiki/Swift:_Convert_between_CGImage,_CIImage_and_UIImage
        func convertCIImageToCGImage(inputImage: CIImage) -> CGImage! {
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(inputImage, from: inputImage.extent){
                return cgImage
            }
            return nil
        }

        var cgImage: CGImage? = nil

        if self.needProcessing {

            // try to apply a cropping filter
            var ciImage = CIImage(cgImage: image.cgImage!)
            let filter = CIFilter(name:"CICrop")
            filter?.setValue(CIVector(x: 500, y: 500, z: 500+224*3, w: 500+224*3), forKey: "inputRectangle")
            filter?.setValue(ciImage, forKey: "inputImage")

            ciImage = (filter?.outputImage)!

            // apply filter for scaling image by factor of 1/3
            // as the image is expected to be 224x224 for these models
            let filter2 = CIFilter(name:"CILanczosScaleTransform")
            filter2?.setValue(0.2, forKey: "inputScale")
            filter2?.setValue(ciImage, forKey: "inputImage")
            ciImage = (filter2?.outputImage)!

            cgImage = convertCIImageToCGImage(inputImage: ciImage)

            self.needProcessing = false
        }
        else{
            // if no processing needed, just set image
            cgImage = image.cgImage
        }

        let newUIImage = UIImage(cgImage: cgImage!, scale: image.scale, orientation: image.imageOrientation)
        self.currentImage = newUIImage
        return newUIImage
    }
}

// MARK: UIImage Extension Code For Preprocessing Images for Prediction
extension UIImage {
    var noir: UIImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        return nil
    }
}


extension UIImage{
    // Resize the cgimage and convert to UIImage
    public func resize(to newSize: CGSize) -> UIImage {
                    UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
            self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            return resizedImage
    }
    
    // Return a UInt8 type of data, a vector representing pixel values
    public func pixelData() -> [UInt8]? {
            let dataSize = size.width * size.height * 4
            var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: &pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            
            guard let cgImage = self.cgImage else { return nil }
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            
            return pixelData
    }

}
