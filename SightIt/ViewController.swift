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
import VectorMath
import os.log

class ViewController: UIViewController, VirtualObjectManagerDelegate {
    
    static let serialQueue = DispatchQueue(label: "com.apple.arkitexample.serialSceneKitQueue")
    
    /// The ARSession that handles tracking and 3D structure estimation
    let session = ARSession()
    
    /// The virtual object manager which controls which objects have been placed into the AR session
    var virtualObjectManager: VirtualObjectManager!
    
    /// A timer to coordinate restarting the ARSession if tracking has been bad for more than 10 seconds.
    var sessionRestartTimer: Timer?
    
    /// AVSpeechSynthesizer for speech feedback
    let synth = AVSpeechSynthesizer()
    
    /// ObjectDetectionManager which makes API call to Azure custom service
    let objDetectionManager = ObjectDetectionManager()
    
    /// The jobs in process
    var jobs = [String: JobInfo]()
    
    /// The timer that allows for auto snapshotting of the environment when a job is active
    var snapshotTimer: Timer?
    
    /// the last time haptic feedback was generated for the user
    var lastGeneratedHapticFeedback: Date!
    
    /// Allows haptic feedback to be communicated to the user
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    /// Keeps track of the last time the name of a particular object was announced
    var lastObjectAnnouncementTimes = [VirtualObject: Date]()
    
    /// Object to find
    let objectToFind = "cup"
    
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
        lastGeneratedHapticFeedback = Date()

        /// For now the app will start finding the object 5 seconds upon start
        announce(announcement: "Started looking for \(objectToFind)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
            self.postNewJob(objectToFind: self.objectToFind)
        })
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
            
            placeVirtualObject(pixelLocation: CGPoint(x: gesture.view!.center.x, y: gesture.view!.center.y), overrideFrameTransform: nil, objectToFind: "plate")
        }
    }
    
    /// Post a new job with the specified name
    ///
    /// - Parameter objectToFind: the name of the object to find
    func postNewJob(objectToFind: String) {
        resetTracking()
        self.snapshotTimer?.invalidate()
        self.snapshotTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: (#selector(self.takeSnapshot(sender:))), userInfo: nil, repeats: true)
    }
    
    /// Take a snapshot of the scene and add it to most recently created job.
    ///
    /// - Parameter doAnnouncement: true if the system should announce that it has taken a snapshot
    @objc func takeSnapshot(sender: Timer) {
        // make sure we have a valid frame and a valid job without a placement
        guard let currentTransform = session.currentFrame?.camera.transform else {
            os_log(.error, "Cannot find camera transform")
            return
        }
        
        let sceneImage = self.sceneView.snapshot()
        let jobID: String = Date().timeIntervalSince1970.description
        self.jobs[jobID] = JobInfo(cameraTransforms: [jobID: currentTransform], sceneImage: sceneImage, objectToFind: objectToFind)
        objDetectionManager.detectObjects(image: sceneImage, objectToFind: ObjectIdentifier(rawValue: objectToFind)!) { (response, error) in
            guard let prediction = response?.bestPrediction, let x = prediction.centerX, let y = prediction.centerY else {
                return
            }
            
            os_log(.debug, "Receiving best prediction")
            self.placeVirtualObject(pixelLocation: CGPoint(x: CGFloat(x), y: CGFloat(y)), overrideFrameTransform: currentTransform, objectToFind: self.objectToFind)
        }
    }
    
    /// Resets (or starts) the tracking session
    func resetTracking() {
        // We want to get rid of any jobs we're waiting on
        jobs.removeAll()
        virtualObjectManager.removeAllVirtualObjects()
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
    func placeVirtualObject(pixelLocation: CGPoint, overrideFrameTransform frameTransform: matrix_float4x4?, objectToFind: String) {
        guard let transform = (frameTransform != nil) ? frameTransform : session.currentFrame?.camera.transform else {
            return
        }
        
        // Create a new virtual object with a label that corresponds to the object name
        let object = VirtualObject(objectToFind: objectToFind)
        let (worldPos, _, _) = self.virtualObjectManager.worldPositionFromScreenPosition(pixelLocation,
                                                                                         in: self.sceneView,
                                                                                         frame_transform: transform,
                                                                                         objectPos: nil)
        
        if worldPos != nil {
            os_log(.debug, "Hit test successfully")
            
            // Stop sending image to Azure
            self.snapshotTimer?.invalidate()
            
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
    
    @objc func getHapticFeedback() {
        guard let frame = sceneView.session.currentFrame else {
            return
        }
        var objectsInRange = [VirtualObject]()
        var objectDistanceStrings = [String]()
        var shouldGiveFeedback: Bool = false

        let curLocation = getRealCoordinates(currentFrame: frame)

        for virtualObject in virtualObjectManager.virtualObjects {
            let referencePosition = virtualObject.cubeNode.convertPosition(SCNVector3(x: curLocation.location.x, y: curLocation.location.y, z: curLocation.location.z), from:sceneView.scene.rootNode)
            let distanceToObject = sqrt(referencePosition.x*referencePosition.x +
                referencePosition.y*referencePosition.y +
                referencePosition.z*referencePosition.z)
            let virtualObjectWorldPosition = virtualObject.cubeNode.convertPosition(SCNVector3(x: 0.0, y: 0.0, z: 0.0), to:sceneView.scene.rootNode)
            // vector from camera to virtual object
            let cameraToObject = Vector3.init(virtualObjectWorldPosition.x - curLocation.location.x,
                                              virtualObjectWorldPosition.y - curLocation.location.y,
                                              virtualObjectWorldPosition.z - curLocation.location.z).normalized()
            let negZAxis = curLocation.transformMatrix*Vector3.init(0.0, 0.0, -1.0)
            let angleDiff = acos(negZAxis.dot(cameraToObject))
            
            if abs(angleDiff) < 0.2 {
                shouldGiveFeedback = true
                var distanceToAnnounce: Float?
                distanceToAnnounce = Float(distanceToObject)
                let distanceString = String(format: "%.1f feet", (distanceToAnnounce!*100.0/2.54/12.0))
                objectsInRange.append(virtualObject)
                objectDistanceStrings.append(distanceString)
            }
        }
        
        if shouldGiveFeedback {
            let timeInterval = lastGeneratedHapticFeedback.timeIntervalSinceNow
            if(-timeInterval > 0.4) {
                feedbackGenerator.impactOccurred()
                lastGeneratedHapticFeedback = Date()
            }
        }
        
        var objectsToAnnounce = ""
        for (idx, object) in objectsInRange.enumerated() {
            let voiceInterval = lastObjectAnnouncementTimes[object]?.timeIntervalSinceNow
            if voiceInterval == nil || -voiceInterval! > 1.0 {
                // TODO: add support for only announcing this when either a switch is toggled or when a button is pressed
                objectsToAnnounce += object.objectToFind + " " + objectDistanceStrings[idx] + "\n"
                lastObjectAnnouncementTimes[object] = Date()
            }
        }
        
        if !objectsToAnnounce.isEmpty {
            announce(announcement: objectsToAnnounce)
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
    
    /// Communicates a message to the user via speech.  If VoiceOver is active, then VoiceOver is used
    /// to communicate the announcement, otherwise we use the AVSpeechEngine
    ///
    /// - Parameter announcement: the text to read to the user
    func announce(announcement: String) {
        if synth.isSpeaking {
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback)
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            let utterance = AVSpeechUtterance(string: announcement)
            utterance.rate = 0.6
            synth.speak(utterance)
        } catch {
            os_log(.error, "Unexpeced error announcing something using AVSpeechEngine!")
        }
    }
    
    /// Gets the x, y, z, yaw and transformation matrix corresponding to the current pose of the camera
    ///
    /// - Parameter sceneView: the scene view (used for looking up the camera transform)
    /// - Returns: the camera's position as a CurrentCoordinateInfo object
    private func getRealCoordinates(currentFrame: ARFrame) -> CurrentCoordinateInfo {
        let x = SCNMatrix4(currentFrame.camera.transform).m41
        let y = SCNMatrix4(currentFrame.camera.transform).m42
        let z = SCNMatrix4(currentFrame.camera.transform).m43
        
        let yaw = currentFrame.camera.eulerAngles.y
        let scn = SCNMatrix4(currentFrame.camera.transform)
        let transMatrix = Matrix3([scn.m11, scn.m12, scn.m13,
                                   scn.m21, scn.m22, scn.m23,
                                   scn.m31, scn.m32, scn.m33])
        
        return CurrentCoordinateInfo(LocationInfo(x: x, y: y, z: z, yaw: yaw), transMatrix: transMatrix)
    }
    
    func detectObjectSample() {
        objDetectionManager.detectObjects(image: UIImage(named: "object1")!, objectToFind: .plate) { (response, error) in
            print(response?.bestPrediction?.tagName)
            print(response?.predictions?.count)
        }
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



