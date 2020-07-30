//
//  ObjectDetectionManager.swift
//  SightIt
//
//  Created by Khang Vu on 7/27/20.
//  Copyright © 2020 SightIt. All rights reserved.
//

import UIKit
import os.log

class ObjectDetectionManager {
    /// Endpoint of Azure custom service
    var endpoint: String?
    
    /// Prediction key of Azure custom service
    var predictionKey: String?
    
    /// Probability threshold
    var threshold: Float = 0.45
    
    /// Max number of object detected in the image frame
    var maxReturns: Int = 5
    
    init() {
        retrieveCredentials()
    }
    
    convenience init(threshold: Float, maxReturns: Int) {
        self.init()
        self.threshold = threshold
        self.maxReturns = maxReturns
    }
    
    /// Trying to find a specific type of object in an image. This function will make an async call to Azure custom service
    /// for image detection
    ///
    /// - Parameters:
    ///   - image: the image frame
    ///   - objectToFind: the type of the object
    ///   - taskCallback: the call back function, which will return ObjectDetectionResponse
    func detectObjects(image: UIImage?, objectToFind: ObjectIdentifier, taskCallback: @escaping(ObjectDetectionResponse?, Error?) -> ()) {
        if endpoint == nil || predictionKey == nil {
            os_log(.error, "Failed to retrieve Azure Custom Service credentials")
            return
        }
        
        if image == nil {
            os_log(.error, "Input image is nil")
            return
        }
        
        let request = createRequest(image!)
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: request) { (data, response, error) in
            var response: ObjectDetectionResponse? = nil
            var err: Error? = nil
            
            guard let data = data, error == nil else {
                taskCallback(nil, error)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: Any]
                print("Response \(json)")
                response = try JSONDecoder().decode(ObjectDetectionResponse.self, from: data)
                self.handleResponse(response)
            } catch {
                err = error
                print("Error \(error)")
            }
            
            taskCallback(response, err)
        }
        task.resume()
    }
    
    /// Process the response by sorting the predictions, filtering out predictions below threshold,
    /// and only return the first best `maxReturns` prediction
    ///
    /// - Parameter response: ObjectDetectionResponse?
    private func handleResponse(_ response: ObjectDetectionResponse?) {
        if response == nil {
            return
        }
        
        // Sort predictions
        response!.predictions = response!.predictions?.sorted(by: { (p1, p2) -> Bool in
            (p1.probability ?? 0) > (p2.probability ?? 0)
        })
        
        // Filter out predictions below threshold
        response!.predictions = response!.predictions?.filter({ (prediction) -> Bool in
            (prediction.probability ?? 0) >= threshold
        })
        
        // Only return the first best `maxReturns` predictions
        response!.predictions = Array(response!.predictions?.prefix(maxReturns) ?? [])
    }
    
    private func retrieveCredentials() {
        if let path = Bundle.main.path(forResource: "azure-custom-vision", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? Dictionary<String, AnyObject> {
                    endpoint = json["endpoint"] as? String
                    predictionKey = json["predictionKey"] as? String
                }
            } catch {
                print("\(error)")
                os_log(.error, "Unable to retrieve Azure Custom Vision credentials. Make sure to include azure-custom-vision.json in your root folder.")
            }
        }
    }
    
    private func createRequest(_ image: UIImage) -> URLRequest {
        let imageData: Data = resizeImage(image, maxDimension: 1024).jpegData(compressionQuality: 0.8)!
        let requestURL = URL(string: endpoint!)!
        var request: URLRequest = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue(predictionKey!, forHTTPHeaderField: "Prediction-Key")
        request.httpBody = imageData
        return request
    }
    
    func resizeImage(_ image: UIImage, maxDimension: Float) -> UIImage {
        let size = image.size
        let maxDimensionGFloat = CGFloat(maxDimension)
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimensionGFloat, height: size.height * maxDimensionGFloat / size.width)
        } else {
            newSize = CGSize(width: size.width * maxDimensionGFloat / size.height,  height: maxDimensionGFloat)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}

class ObjectDetectionResponse: Decodable {
    var predictions: [PredictionResult]?
    var bestPrediction: PredictionResult? {
        get {
            if _bestPrediction != nil {
                return _bestPrediction
            }
            
            if predictions == nil {
                return nil
            }
            
            var maxProbability: Float = 0
            for p in predictions! {
                if p.probability! > maxProbability {
                    _bestPrediction = p
                    maxProbability = p.probability!
                }
            }
            
            return _bestPrediction
        }
    }
    private var _bestPrediction: PredictionResult?
}

class PredictionResult: Decodable {
    var probability: Float?
    var tagId: String?
    var tagName: ObjectIdentifier
    var boundingBox: BoundingBox?
    
    /// The x percentage of the center coordinate (i.e. 0 - 1 )
    var centerX: Float? {
        get {
            if boundingBox?.left == nil || boundingBox?.width == nil {
                return nil
            }
            return boundingBox!.left! + boundingBox!.width! / 2
        }
    }
    
    /// The y percentage of the center coordinate (i.e. 0 - 1 )
    var centerY: Float? {
        get {
            if boundingBox?.top == nil || boundingBox?.height == nil {
                return nil
            }
            return boundingBox!.top! + boundingBox!.height! / 2
        }
    }
}

enum ObjectIdentifier: String, Codable {
    case plate
    case cup
    case fork
    case spoon
    case knife
}

class BoundingBox: Decodable {
    var height: Float?
    var left: Float?
    var top: Float?
    var width: Float?
}
