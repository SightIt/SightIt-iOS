//
//  ViewController.swift
//  SightIt
//
//  Created by Khang Vu on 7/26/20.
//  Copyright © 2020 SightIt. All rights reserved.
//

import ARKit
import Foundation
import SceneKit
import UIKit
import os.log

class ViewController: UIViewController, VirtualObjectManagerDelegate {
    
    static let serialQueue = DispatchQueue(label: "com.apple.arkitexample.serialSceneKitQueue")
    
    /// The ARSession that handles tracking and 3D structure estimation
    let session = ARSession()
    
    /// The virtual object manager which controls which objects have been placed into the AR session
    var virtualObjectManager: VirtualObjectManager!
    
    /// A timer to coordinate restarting the ARSession if tracking has been bad for more than 10 seconds.
    var sessionRestartTimer: Timer?
    
    /// The main view that captures the AR scene and controls world tracking
    @IBOutlet weak var sceneView: ARSCNView!
    
    /// The standard ARSession configuration.  The configuration uses 6DOF tracking as
    /// well as horizontal and vertical (when available) plane detection
    let standardConfiguration: ARWorldTrackingConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        if #available(iOS 11.3, *) {
            configuration.planeDetection = [.horizontal, .vertical]
        } else {
            // Fallback on earlier versions
            configuration.planeDetection = [.horizontal]
        }
        return configuration
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        
        // TODO: this temporarily set up tapGesture on the AR View to get a 2D pixel location
        // on the screen and place a virtual object in the 3D world. We'd like to obtain this location
        // from image detection results
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSceneTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    /// Called when the view appears on the screen.  Above what is done by the super class, this function does the following.
    /// * Display an error message if the user's device doesn't support 6DOF tracking (e.g., for phones older than the iPhone 6S)
    /// * Restart the tracking session
    /// * Add a listener for the end of any VoiceOver announcements so we can note this.
    ///
    /// - Parameter animated: whether or not to animate
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed after a while.
        UIApplication.shared.isIdleTimerDisabled = true
        
        if ARWorldTrackingConfiguration.isSupported {
            // Start the ARSession.
            resetTracking()
        } else {
            // This device does not support 6DOF world tracking.
            os_log(.error, "This device does not support 6DOF world tracking.")
            
            // TODO: Display/announce some message to the user
            //            let sessionErrorMsg = "This app requires world tracking. World tracking is only available on iOS devices with A9 processor or newer. " +
            //            "Please quit the application."
            //            displayErrorMessage(title: "Unsupported platform", message: sessionErrorMsg, allowRestart: false)
        }
    }
    
    /// TODO: This function is temporarily added to place virtual object upon scene tapped
    @objc func handleSceneTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.view != nil else { return }
        
        if gesture.state == .ended {      // Move the view down and to the right when tapped.
            //            os_log(.debug, "User tapped the scene at x: %{public}@, y: %{public}@", gesture.view!.center.x, gesture.view!.center.y)
            self.virtualObjectManager.removeAllVirtualObjects()
            
            placeVirtualObject(pixelLocation: CGPoint(x: gesture.view!.center.x, y: gesture.view!.center.y), overrideFrameTransform: nil)
        }
    }
    
    /// Resets (or starts) the tracking session
    func resetTracking() {
        // TODO: would probably have a queue of image detection jobs here.
        // We want to get rid of any jobs we're waiting on
        //        jobs.removeAll()
        session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
        
        // reset timer
        if sessionRestartTimer != nil {
            sessionRestartTimer!.invalidate()
            sessionRestartTimer = nil
        }
    }
    
    /// Place a virtual object at a particular position
    ///
    /// - Parameters:
    ///   - pixelLocation: the point (2D) to use for creating the ray
    ///   - overrideFrameTransform: if set, use the specified frame transform instead
    ///        of the one of the current frame.
    func placeVirtualObject(pixelLocation: CGPoint, overrideFrameTransform frameTransform: matrix_float4x4?) {
        guard let transform = (frameTransform != nil) ? frameTransform : session.currentFrame?.camera.transform else {
            return
        }
        
        // Create a new virtual object with a label that corresponds to the object name
        let object = VirtualObject(objectToFind: "nameOfObject")
        let (worldPos, _, _) = self.virtualObjectManager.worldPositionFromScreenPosition(pixelLocation,
                                                                                         in: self.sceneView,
                                                                                         frame_transform: transform,
                                                                                         objectPos: nil)
        
        if worldPos != nil {
            os_log(.debug, "Hit test successfully")
            // Place the cube with the floating label of the job into the scene and announce that the object has been found to the user
            self.virtualObjectManager.loadVirtualObject(object, to: worldPos!, cameraTransform: transform)
            
            if object.parent == nil {
                ViewController.serialQueue.async {
                    self.sceneView.scene.rootNode.addChildNode(object)
                    os_log(.debug, "Found the object!")
                }
            }
        } else {
            os_log(.error, "Failed to place virtual object. worldPos is nil")
        }
    }
    
    
    
    // MARK: - VirtualObjectManager delegate callbacks
    
    /// Called when the virtual object manager is loading an object.  Since this could be a long running operation (although it isn't given we only use a cube for our object now), display a spinner
    ///
    /// - Parameters:
    ///   - manager: the virtual object manager
    ///   - object: the virtual object that will load
    func virtualObjectManager(_ manager: VirtualObjectManager, willLoad object: VirtualObject) {
        DispatchQueue.main.async {
            // Show progress indicator
            //            self.spinner = UIActivityIndicatorView()
            //            self.spinner!.center = self.addObjectButton.center
            //            self.spinner!.bounds.size = CGSize(width: self.addObjectButton.bounds.width - 5, height: self.addObjectButton.bounds.height - 5)
            //            self.addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])
            //            self.sceneView.addSubview(self.spinner!)
            //            self.spinner!.startAnimating()
            //
            //            self.isLoadingObject = true
        }
    }
    
    /// Called by the virtual object manager to signal that the object is done loading.  This allows the ViewController to remove the progress spinner
    ///
    /// - Parameters:
    ///   - manager: the virtual object manager
    ///   - object: the virtual object that has just loaded
    func virtualObjectManager(_ manager: VirtualObjectManager, didLoad object: VirtualObject) {
        DispatchQueue.main.async {
            //            self.isLoadingObject = false
            //
            //            // Remove progress indicator
            //            self.spinner?.removeFromSuperview()
            //            self.addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
            //            self.addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])
        }
    }
    
    /// Setup the ARSCNView by creating the object manager and setting various ARSCNView properties.
    func setupScene() {
        virtualObjectManager = VirtualObjectManager()
        virtualObjectManager.delegate = self
        
        // set up scene view
        sceneView.setup()
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        sceneView.delegate = self
        sceneView.session = session
        sceneView.showsStatistics = false
    }
}


extension ViewController : ARSCNViewDelegate {
    /// Listen for any state changes to the ARSession.
    /// This is useful for doing things like restarting a session after bad tracking and communicating warning messages to the user.
    ///
    /// - Parameters:
    ///   - session: the session object itself
    ///   - camera: the camera object
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            os_log(.error, "AR session is not available")
        case .limited:
            os_log(.error, "AR session is limited")
            // After 10 seconds of limited quality, restart the session
            sessionRestartTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { _ in
            })
        case .normal:
            os_log(.debug, "AR session is normal")
            if sessionRestartTimer != nil {
                sessionRestartTimer!.invalidate()
                sessionRestartTimer = nil
            }
        }
    }
    
    
    /// - Tag: PlaceARContent
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a custom object to visualize the plane geometry and extent.
        let plane = Plane(anchor: planeAnchor, in: sceneView)
        
        // Add the visualization to the ARKit-managed node so that it tracks
        // changes in the plane anchor as plane estimation continues.
        node.addChildNode(plane)
        
        self.virtualObjectManager.addPlane(plane: plane)
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        resetTracking()
    }
    
    
    /// - Tag: UpdateARContent
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? Plane
            else { return }
        
        // Update ARSCNPlaneGeometry to the anchor's new estimated shape.
        if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }
        
        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.extentNode.simdPosition = planeAnchor.center
        }
        
        
        
        
        // Update the plane's classification and the text position
        if #available(iOS 12.0, *),
            let classificationNode = plane.classificationNode,
            let classificationGeometry = classificationNode.geometry as? SCNText {
            let currentClassification = planeAnchor.classification.description
            if let oldClassification = classificationGeometry.string as? String, oldClassification != currentClassification {
                classificationGeometry.string = currentClassification
                classificationNode.centerAlign()
            }
        }
        
    }
    
    
}



