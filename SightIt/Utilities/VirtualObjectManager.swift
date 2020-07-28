//
//  VirtualObjectManager.swift
//  SightIt
//
//  Created by Khang Vu on 7/26/20.
//  Copyright © 2020 SightIt. All rights reserved.
//

import Foundation
import ARKit

/// A class to manage all of the virtual objects that have been placed into this
/// ARSCNView.  Virtual objects in this case correspond to localization jobs the user
/// has created and that have been successfully localized by crowd volunteers.
class VirtualObjectManager {
    
    /// The delegate to inform of any events
    weak var delegate: VirtualObjectManagerDelegate?
    
    /// The virtual objects that have been placed
    var virtualObjects = [VirtualObject]()
    /// The most recently placed virtual object
    var lastUsedObject: VirtualObject?
    /// The planes that are being tracked (these are updated via ARSession delegate calls)
    var planes: [Plane] = []
    
    // MARK: - Resetting objects
    /// Remove all the objects that have been placed in the scene
    func removeAllVirtualObjects() {
        for object in virtualObjects {
            unloadVirtualObject(object)
        }
        virtualObjects.removeAll()
    }
    
    /// Add a plane
    ///
    /// - Parameter plane: the plane description
    func addPlane(plane: Plane) {
        // add the plane so we can do our own custom hit testing later
        planes.append(plane)
        
        print("Number of planes: \(planes.count)")
    }
    
    /// Remove a plane
    ///
    /// - Parameter plane: the plane description
    func removePlane(anchor: ARPlaneAnchor) {
        // remove the plane since it is no longer valid
        planes = planes.filter { $0.anchor != anchor }
    }

    
    /// Remove the specified virtual object from the scene
    ///
    /// - Parameter object: the virtual object to remove
    private func unloadVirtualObject(_ object: VirtualObject) {
        ViewController.serialQueue.async {
            object.removeFromParentNode()
            if self.lastUsedObject == object {
                self.lastUsedObject = nil
                if self.virtualObjects.count > 1 {
                    self.lastUsedObject = self.virtualObjects[0]
                }
            }
        }
    }
    
    // MARK: - Loading object
    
    /// Load a virtual object at a particular position with a particular camera transform
    ///
    /// - Parameters:
    ///   - object: the virtual object to put into the scene
    ///   - position: the position of the object relative to the camera
    ///   - cameraTransform: the camera transform
    func loadVirtualObject(_ object: VirtualObject, to position: SIMD3<Float>, cameraTransform: matrix_float4x4) {
        self.virtualObjects.append(object)
        self.delegate?.virtualObjectManager(self, willLoad: object)
        
        // Load the content asynchronously.
        DispatchQueue.global().async {
            // Immediately place the object in 3D space.
            ViewController.serialQueue.async {
                self.setNewVirtualObjectPosition(object, to: position, cameraTransform: cameraTransform)
                self.lastUsedObject = object
                
                self.delegate?.virtualObjectManager(self, didLoad: object)
            }
        }
    }
    
    /// Move the virtual object
    ///
    /// - Parameters:
    ///   - object: the object to move
    ///   - pos: the new x, y, z position (relative to the camera)
    ///   - cameraTransform: the transform of the camera
    private func setNewVirtualObjectPosition(_ object: VirtualObject, to pos: SIMD3<Float>, cameraTransform: matrix_float4x4) {
        let cameraWorldPos = cameraTransform.translation
        var cameraToPosition = pos - cameraWorldPos
        
        // Limit the distance of the object from the camera to a maximum of 10 meters.
        if simd_length(cameraToPosition) > 10 {
            cameraToPosition = simd_normalize(cameraToPosition)
            cameraToPosition *= 10
        }
        
        object.simdPosition = cameraWorldPos + cameraToPosition
    }
    
    
    /// If an object was placed near a newly discovered plane, we may decide to move it to the plane using this function.
    ///
    /// - Parameters:
    ///   - anchor: the plane we are testing
    ///   - planeAnchorNode: the scene node corresponding to the plane (TODO: we already have the Plane class that wraps these two objects together, not sure whey we are not just using that.)
    func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor, planeAnchorNode: SCNNode) {
        for object in virtualObjects {
            // Get the object's position in the plane's coordinate system.
            let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)
            
            if objectPos.y == 0 {
                return; // The object is already on the plane - nothing to do here.
            }
            
            // Add 10% tolerance to the corners of the plane.
            let tolerance: Float = 0.1
            
            let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
            let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
            let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
            let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
            
            if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
                return
            }
            
            // Move the object onto the plane if it is near it (within 5 centimeters).
            let verticalAllowance: Float = 0.05
            let epsilon: Float = 0.001 // Do not bother updating if the different is less than a mm.
            let distanceToPlane = abs(objectPos.y)
            if distanceToPlane > epsilon && distanceToPlane < verticalAllowance {
                delegate?.virtualObjectManager(self, didMoveObjectOntoNearbyPlane: object)
                
                SCNTransaction.begin()
                SCNTransaction.animationDuration = CFTimeInterval(distanceToPlane * 500) // Move 2 mm per second.
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                object.position.y = anchor.transform.columns.3.y
                SCNTransaction.commit()
            }
        }
    }
    
    /// Calculate the transform for a virtual object relative to a camera (distance, rotation, and scale)
    ///
    /// - Parameters:
    ///   - object: the virtual object
    ///   - cameraTransform: the camera transform
    /// - Returns: the transform information
    func transform(for object: VirtualObject, cameraTransform: matrix_float4x4) -> (distance: Float, rotation: Int, scale: Float) {
        let cameraPos = cameraTransform.translation
        let vectorToCamera = cameraPos - object.simdPosition
        
        let distanceToUser = simd_length(vectorToCamera)
        
        var angleDegrees = Int((object.eulerAngles.y * 180) / .pi) % 360
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        
        return (distanceToUser, angleDegrees, object.scale.x)
    }
    
    /// Attempt to compute the coordinates of an object (as specified by a 2D pixel location) in the world
    /// coordinate system.  This function assumes that we only have one localization of the object.
    /// If we have two (ideally from the same user), we can use worldPositionFromStereoScreenPosition.
    ///
    /// - Parameters:
    ///   - position: the pixel coordinate of the localization
    ///   - sceneView: the AR scene view
    ///   - frame_transform: the transformation of the frame in which the localization was registered (since it need not be for the current frame)
    ///   - objectPos: the position of the object if it has already been placed into the scene
    /// - Returns: an optional position in 3D, an optional plane anchor, and Boolean that is true iff the object was located on a plane
    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         in sceneView: ARSCNView,
                                         frame_transform : matrix_float4x4,
                                         objectPos: SIMD3<Float>?) -> (position: SIMD3<Float>?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
        // TODO:  In some cases an object sits high above a plane.  Such as a chair on the floor.  In this
        // case you want to first test for a feature point hit, and if the feature point is sufficiently
        // far from a plane hit, you should default to the feature point, else use the plane.
        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting plane anchors first.
        //    (If any such anchors exist & only within their extents.)
        // In order to use the hit test from the point of view of the previous frame, we have to do it manually ourselves
        guard let ray = sceneView.hitTestRayFromScreenPos(position, overrideFrameTransform: frame_transform) else {
            return (nil, nil, false)
        }
        var worldCoordinatesForPlaneHit: SIMD3<Float>?
        var planeAnchorForPlaneHit: ARPlaneAnchor?
        var closestPlane:Float?
        
        for plane in planes {
            guard let sceneNode = sceneView.node(for: plane.anchor) else {
                continue
            }
            let newOrigin = sceneNode.convertPosition(SCNVector3(ray.origin), from: sceneView.scene.rootNode)
            let newDirection = sceneNode.convertVector(SCNVector3(ray.direction), from: sceneView.scene.rootNode)
            // in the plane's local coordinate system, the normal always points in the positive y direction
            let distanceToPlane = -newOrigin.y / newDirection.y
            
            if distanceToPlane > 0 && (closestPlane == nil || distanceToPlane < closestPlane!) {
                let collisionPointInPlaneCoordinateSystem = SCNVector3(x: newOrigin.x + distanceToPlane*newDirection.x,
                                                                       y: newOrigin.y + distanceToPlane*newDirection.y,
                                                                       z: newOrigin.z + distanceToPlane*newDirection.z)
                if abs(collisionPointInPlaneCoordinateSystem.x - plane.anchor.center.x) <= plane.anchor.extent.x/2.0 &&
                    abs(collisionPointInPlaneCoordinateSystem.z - plane.anchor.center.z) <= plane.anchor.extent.z/2.0 {
                    closestPlane = distanceToPlane
                    
                    worldCoordinatesForPlaneHit = SIMD3<Float>(sceneView.scene.rootNode.convertPosition(collisionPointInPlaneCoordinateSystem, from: sceneNode))
                    planeAnchorForPlaneHit = plane.anchor
                }
            }
        }
        if worldCoordinatesForPlaneHit != nil {
            print("Found the point on the plane", worldCoordinatesForPlaneHit!)
            return (worldCoordinatesForPlaneHit, planeAnchorForPlaneHit, true)
        }
        
        // -------------------------------------------------------------------------------
        // 2. Collect more information about the environment by hit testing against
        //    the feature point cloud. (currenty unsupported, but might be worth revisiting)
        
        return (nil, nil, false)
    }
    
    /// Attempt to compute the coordinates of an object (as specified by a 2D pixel location) in the world
    /// coordinate system using two localizations of the object.
    /// The function uses methods for stereo triangulation.
    ///
    /// - Parameters:
    ///   - pixel_location_1: the pixel coordinate of the first localization
    ///   - pixel_location_2: the pixel coordinate of the second localization
    ///   - sceneView: the AR scene view
    ///   - frame_transform_1: the transformation of the frame in the first localization (since it need not be for the current frame)
    ///   - frame_transform_2: the transformation of the frame in the second localization (since it need not be for the current frame)
    ///   - objectPos: the position of the object if it has already been placed into the scene
    /// - Returns: an optional position in 3D, an optional plane anchor, and Boolean that is true iff the object was located on a plane
    func worldPositionFromStereoScreenPosition(pixel_location_1: CGPoint,
                                               pixel_location_2: CGPoint,
                                               in sceneView: ARSCNView,
                                               frame_transform_1 : matrix_float4x4,
                                               frame_transform_2 : matrix_float4x4,
                                               objectPos: SIMD3<Float>?) -> (position: SIMD3<Float>?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
        // TODO:  In some cases an object sits high above a plane.  Such as a chair on the floor.  In this
        // case you want to first test for a feature point hit, and if the feature point is sufficiently
        // far from a plane hit, you should default to the feature point, else use the plane.
        guard let ray1 = sceneView.hitTestRayFromScreenPos(pixel_location_1, overrideFrameTransform: frame_transform_1),
            let ray2 = sceneView.hitTestRayFromScreenPos(pixel_location_2, overrideFrameTransform: frame_transform_2) else {
                return (nil, nil, false)
        }
        
        // compute closest point between the two rays using the method described here: http://morroworks.com/Content/Docs/Rays%20closest%20point.pdf
        let A = ray1.origin
        let B = ray2.origin
        let a = ray1.direction
        let b = ray2.direction
        let c = B - A
        let D = A + a*(-simd_dot(a,b)*simd_dot(b,c)+simd_dot(a,c)*simd_dot(b,b))/(simd_dot(a,a)*simd_dot(b,b) - simd_dot(a,b)*simd_dot(a,b))
        let E = B + b*(simd_dot(a,b)*simd_dot(a,c)-simd_dot(b,c)*simd_dot(a,a))/(simd_dot(a,a)*simd_dot(b,b) - simd_dot(a,b)*simd_dot(a,b))
        let closestPoint = (D + E)/2
        // we probably want to do sanity checks on this
        return (closestPoint, nil, false)
    }
}

// MARK: - Delegate
/// A protocol to handle various types of notifications generated by the VirtualObjectManager
protocol VirtualObjectManagerDelegate: class {
    /// Called when a virtual object is about to load
    ///
    /// - Parameters:
    ///   - manager: the virtual object manager
    ///   - object: the virtual object that is going to load
    func virtualObjectManager(_ manager: VirtualObjectManager, willLoad object: VirtualObject)
    
    /// Called when a virtual object is done loading
    ///
    /// - Parameters:
    ///   - manager: the virtual object manager
    ///   - object: the virtual object that finished loading
    func virtualObjectManager(_ manager: VirtualObjectManager, didLoad object: VirtualObject)
    
    /// Called when an object's transform changes (e.g., due to it moving)
    ///
    /// - Parameters:
    ///   - manager: the virtual object manager
    ///   - object: the object that has a new transform
    func virtualObjectManager(_ manager: VirtualObjectManager, transformDidChangeFor object: VirtualObject)
    
    /// Called when an object that was previously placed is moved onto a Plane
    ///
    /// - Parameters:
    ///   - manager: the virtual object manager
    ///   - object: the object that was moved on to a plane
    func virtualObjectManager(_ manager: VirtualObjectManager, didMoveObjectOntoNearbyPlane object: VirtualObject)
}

// Optional protocol methods
extension VirtualObjectManagerDelegate {
    /// Called when an object's transform changes (e.g., due to it moving)
    /// The default implementation does nothing
    ///
    /// - Parameters:
    ///   - manager: the virtual object manager
    ///   - object: the object that has a new transform
    func virtualObjectManager(_ manager: VirtualObjectManager, transformDidChangeFor object: VirtualObject) {}
    
    /// Called when an object that was previously placed is moved onto a Plane
    /// The default implementation does nothing
    ///
    /// - Parameters:
    ///   - manager: the virtual object manager
    ///   - object: the object that was moved on to a plane
    func virtualObjectManager(_ manager: VirtualObjectManager, didMoveObjectOntoNearbyPlane object: VirtualObject) {}
}
