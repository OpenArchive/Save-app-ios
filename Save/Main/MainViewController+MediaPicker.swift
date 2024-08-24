//
//  Created by Richard Puckett on 8/22/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import AVFoundation
import UIKit

extension MainViewController: UIImagePickerControllerDelegate {
    public func getListOfCameras() -> [AVCaptureDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: .back)
        
        return session.devices
    }
    
    func getImageFromUser(
        title: String = "Adding Media",
        message: String = "Where is your media located?",
        completion: @escaping (_ image: UIImage?, _ error: NSError?) -> Void) {
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            
            if !getListOfCameras().isEmpty {
                alert.addAction(UIAlertAction(title: "Phone Camera", style: .default, handler: { _ in
                    self.openCamera()
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Phone Gallery", style: .default, handler: { _ in
                self.openPhoneGallery()
            }))
            
            if UIPasteboard.general.hasImages {
                alert.addAction(UIAlertAction(title: "Pasteboard", style: .default, handler: { _ in
                    self.handlePasteboard()
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            }))
            
            self.present(alert, animated: true)
        }
    
    func handlePasteboard() {
        guard let image = UIPasteboard.general.image else {
            log.debug("No image in pasteboard any more")
            // pickerDelegate.pickerCompletion?(nil, GeneralError.imageNotFound as NSError)
            return
        }
        
        // pickerDelegate.pickerCompletion?(image, nil)
    }
    
    func openCamera() {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.allowsEditing = false
        vc.delegate = self
        
        present(vc, animated: true)
    }
    
    func openPhoneGallery() {
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = self
        
        present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        log.debug("Got m")
        
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[.originalImage] as? UIImage else {
            return
        }
        
        log.debug("XXX original image size = \(image.size)")
    }
}
