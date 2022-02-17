//
//  ViewController.swift
//  MaskDetector
//
//  Created by Prashant Gaikwad on 19/09/20.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController, UINavigationControllerDelegate {

    //MARK: - IBOutlets
    @IBOutlet weak var detectionLabel: UILabel!
    @IBOutlet weak var photoImageView: UIImageView?
    
    //MARK: - Properties
    lazy var detectionRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: MaskDetector().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processDetections(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    //MARK: - IBAction
    @IBAction func testPhoto(sender: UIButton) {
        let pickerVC = UIImagePickerController()
        pickerVC.sourceType = .photoLibrary
        pickerVC.delegate = self
        present(pickerVC, animated: true)
    }
    
    //MARK: - Custom Methods
    private func updateDetections(for image: UIImage) {

        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!)
            do {
                try handler.perform([self.detectionRequest])
            } catch {
                print("Failed to perform detection.\n\(error.localizedDescription)")
            }
        }
    }
    
    private func processDetections(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                print("Unable to detect anything.\n\(error!.localizedDescription)")
                self.detectionLabel.text = "Unable to detect anything.\n\(error!.localizedDescription)"
                return
            }
            
            if results.isEmpty {
                self.detectionLabel.text = "Nothing recognized.\nPlease try again."
            } else {
                let detections = results as! [VNRecognizedObjectObservation]
                self.drawDetectionsOnPreview(detections: detections)
            }
        }
    }
    
    
    func drawDetectionsOnPreview(detections: [VNRecognizedObjectObservation]) {
        guard let image = self.photoImageView?.image else {
            return
        }
        
        let imageSize = image.size
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)

        image.draw(at: CGPoint.zero)

        for detection in detections {
            
            self.detectionLabel.text = "Detections:\n" + detection.labels.map({"\($0.identifier) confidence: \(String(format: "%.2f", $0.confidence * 100))) " + "% " }).joined(separator: "\n")
                        
            //The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
            let boundingBox = detection.boundingBox
            let rectangle = CGRect(x: boundingBox.minX*image.size.width, y: (1-boundingBox.minY-boundingBox.height)*image.size.height, width: boundingBox.width*image.size.width, height: boundingBox.height*image.size.height)
            UIColor(red: 1, green: 0, blue: 0, alpha: 0.4).setFill()
            UIRectFillUsingBlendMode(rectangle, CGBlendMode.normal)
        }
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.photoImageView?.image = newImage
    }
}



extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            return
        }

        self.photoImageView?.image = image
        
        updateDetections(for: image)
    }
}


