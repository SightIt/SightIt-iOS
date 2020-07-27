//
//  Utilities.swift
//  SightIt
//
//  Created by Khang Vu on 7/26/20.
//  Copyright © 2020 SightIt. All rights reserved.
//

import Foundation
import ARKit
import simd

// MARK: - Collection extensions
extension Array where Iterator.Element == Float {
    /// The average of a collection of Float
    var average: Float? {
        guard !self.isEmpty else {
            return nil
        }
        
        let sum = self.reduce(Float(0)) { current, next in
            return current + next
        }
        return sum / Float(self.count)
    }
}

extension Array where Iterator.Element == SIMD3<Float> {
    /// The average of a collection of float3
    var average: SIMD3<Float>? {
        guard !self.isEmpty else {
            return nil
        }
  
        let sum = self.reduce(SIMD3<Float>(repeating: 0)) { current, next in
            return current + next
        }
        return sum / Float(self.count)
    }
}

extension RangeReplaceableCollection {
    /// Remove all but the last n elements of a collection
    ///
    /// - Parameter elementsToKeep: how many elements to keep from the end of the collection
    mutating func keepLast(_ elementsToKeep: Int) {
        if count > elementsToKeep {
            self.removeFirst(count - elementsToKeep)
        }
    }
}

// MARK: - SCNNode extension
extension SCNNode {
    /// Set the scale of the scene node.  Currently this scales uniformly in the x, y, and z directions
    ///
    /// - Parameter scale: the scale factor to apply
    func setUniformScale(_ scale: Float) {
        self.simdScale = SIMD3<Float>(scale, scale, scale)
    }
    
    /// Controls whether or not the scene node should render on top of other nodes
    ///
    /// - Parameter enable: true to enable rendering on top, false otherwise
    func renderOnTop(_ enable: Bool) {
        self.renderingOrder = enable ? 2 : 0
        if let geom = self.geometry {
            for material in geom.materials {
                material.readsFromDepthBuffer = enable ? false : true
            }
        }
        for child in self.childNodes {
            child.renderOnTop(enable)
        }
    }
}

// MARK: - float4x4 extensions
extension float4x4 {
    /// Treats matrix as a (right-hand column-major convention) transform matrix
    /// and factors out the translation component of the transform.
    var translation: SIMD3<Float> {
        let translation = self.columns.3
        return SIMD3<Float>(translation.x, translation.y, translation.z)
    }
}

///// A subclass of SCNNode that stores the position an orientation of a plane (as tracked by an ARSession)
//class Plane: SCNNode {
//    
//    // MARK: - Properties
//    
//    /// The anchor in the ARSession (this contains things like position and orientation of the plane)
//    var anchor: ARPlaneAnchor
//    
//    // MARK: - Initialization
//    
//    /// Initialize a new plane given an ARPlaneAnchor
//    ///
//    /// - Parameter anchor: the plane anchor
//    init(_ anchor: ARPlaneAnchor) {
//        self.anchor = anchor
//        super.init()
//    }
//    
//    /// This hasn't been implemented.
//    ///
//    /// - Parameter aDecoder: the coder object
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    // MARK: - ARKit
//    
//    /// Update the plane anchor (usually in response to some notification from ARSession)
//    ///
//    /// - Parameter anchor: the new plane parameters
//    func update(_ anchor: ARPlaneAnchor) {
//        self.anchor = anchor
//    }
//        
//}



// MARK: - CGPoint extensions
extension CGPoint {
    /// Initialize a point with a specified size
    ///
    /// - Parameter size: the point's size
    init(_ size: CGSize) {
        self.init()
        self.x = size.width
        self.y = size.height
    }
    
    /// Initialize a point from a SCNVector3 (ignores the z coordinate)
    ///
    /// - Parameter vector: the position of the point
    init(_ vector: SCNVector3) {
        self.init()
        self.x = CGFloat(vector.x)
        self.y = CGFloat(vector.y)
    }
    
    /// Gets the distance to another point
    ///
    /// - Parameter point: the other point
    /// - Returns: the distance between the points
    func distanceTo(_ point: CGPoint) -> CGFloat {
        return (self - point).length()
    }
    
    /// Get the length of a point when considering at as a vector in 2D
    ///
    /// - Returns: the length of the point
    func length() -> CGFloat {
        return sqrt(self.x * self.x + self.y * self.y)
    }
    
    /// The point in between this point and another
    ///
    /// - Parameter point: the other point
    /// - Returns: the midpoint
    func midpoint(_ point: CGPoint) -> CGPoint {
        return (self + point) / 2
    }
    /// Add two points
    ///
    /// - Parameters:
    ///   - left: point LHS
    ///   - right: point RHS
    /// - Returns: the sum of the two points
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    
    /// Subtract two points
    ///
    /// - Parameters:
    ///   - left: point LHS
    ///   - right: point RHS
    /// - Returns: the sum of the two points
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    
    /// Add two points and store the results in the LHS point
    ///
    /// - Parameters:
    ///   - left: point LHS (the result is stored here)
    ///   - right: point RHS
    static func += (left: inout CGPoint, right: CGPoint) {
        left = left + right
    }

    /// Subtract two points and store the results in the LHS point
    ///
    /// - Parameters:
    ///   - left: point LHS (the result is stored here)
    ///   - right: point RHS
    static func -= (left: inout CGPoint, right: CGPoint) {
        left = left - right
    }

    /// Divide a point by a scalar
    ///
    /// - Parameters:
    ///   - left: point LHS
    ///   - right: the scalar to divide by
    /// - Returns: a point that has been divided by the scalar
    static func / (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x / right, y: left.y / right)
    }
 
    /// Multiply a point by a scalar
    ///
    /// - Parameters:
    ///   - left: point LHS
    ///   - right: the scalar to divide by
    /// - Returns: a point that has been multiplied by the scalar
    static func * (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x * right, y: left.y * right)
    }
    
    /// Divide a point by a scalar and store it in left
    ///
    /// - Parameters:
    ///   - left: the LHS point (the result is stored here)
    ///   - right: the scalar to divide by
    static func /= (left: inout CGPoint, right: CGFloat) {
        left = left / right
    }

    /// Multiply a point by a scalar and store it in left
    ///
    /// - Parameters:
    ///   - left: the LHS point (the result is stored here)
    ///   - right: the scalar to multiply by
    static func *= (left: inout CGPoint, right: CGFloat) {
        left = left * right
    }
}

// MARK: - CGSize extensions
extension CGSize {
    /// Initiatlize a CGSize with specified width and height
    ///
    /// - Parameter point: the point to use to se width (x) and height (y)
    init(_ point: CGPoint) {
        self.init()
        self.width = point.x
        self.height = point.y
    }

    /// Add two CGSizes (the width and height of each are added to form the result)
    ///
    /// - Parameters:
    ///   - left: the LHS CGSize
    ///   - right: the RHS CGSize
    /// - Returns: the sum of the two CGSizes
    static func + (left: CGSize, right: CGSize) -> CGSize {
        return CGSize(width: left.width + right.width, height: left.height + right.height)
    }

    /// Subtract two CGSizes (the width and height of each are subtracted to form the result)
    ///
    /// - Parameters:
    ///   - left: the LHS CGSize
    ///   - right: the RHS CGSize
    /// - Returns: the difference of the two CGSizes
    static func - (left: CGSize, right: CGSize) -> CGSize {
        return CGSize(width: left.width - right.width, height: left.height - right.height)
    }

    /// Add two CGSizes (the width and height of each are added to form the result) and store the result in left
    ///
    /// - Parameters:
    ///   - left: the LHS CGSize (result is stored here)
    ///   - right: the RHS CGSize
    static func += (left: inout CGSize, right: CGSize) {
        left = left + right
    }

    /// Subtract two CGSizes (the width and height of each are subtracted to form the result) and store the result in left
    ///
    /// - Parameters:
    ///   - left: the LHS CGSize (result is stored here)
    ///   - right: the RHS CGSize
    static func -= (left: inout CGSize, right: CGSize) {
        left = left - right
    }

    /// Divide two CGSizes (the width and height of each are divided to form the result)
    ///
    /// - Parameters:
    ///   - left: the LHS CGSize
    ///   - right: the RHS CGSize
    /// - Returns: the quotient of the two CGSizes
    static func / (left: CGSize, right: CGFloat) -> CGSize {
        return CGSize(width: left.width / right, height: left.height / right)
    }

    /// Multiply two CGSizes (the width and height of each are multiplied to form the result)
    ///
    /// - Parameters:
    ///   - left: the LHS CGSize
    ///   - right: the RHS CGSize
    /// - Returns: the product of the two CGSizes
    static func * (left: CGSize, right: CGFloat) -> CGSize {
        return CGSize(width: left.width * right, height: left.height * right)
    }

    /// Divide two CGSizes (the width and height of each are divided to form the result) and store the result in left
    ///
    /// - Parameters:
    ///   - left: the LHS CGSize (the result is stored here)
    ///   - right: the RHS CGSize
    static func /= (left: inout CGSize, right: CGFloat) {
        left = left / right
    }

    /// Multiply two CGSizes (the width and height of each are multiplied to form the result) and store the result in left
    ///
    /// - Parameters:
    ///   - left: the LHS CGSize (the result is stored here)
    ///   - right: the RHS CGSize
    static func *= (left: inout CGSize, right: CGFloat) {
        left = left * right
    }
}

// MARK: - CGRect extensions
extension CGRect {
    /// The mid point of a rectangle
    var mid: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}

/// Intersect a ray with an infinite horizontal plane (this is useful for testing intersections with the ground plane) (TODO: we can leverage this for finding objects that don't have any meaningful height).
///
/// - Parameters:
///   - rayOrigin: the origin of the ray
///   - direction: the direction of the ray
///   - planeY: the height of the ray
/// - Returns: the position of intersection with the horizontal plane
func rayIntersectionWithHorizontalPlane(rayOrigin: SIMD3<Float>, direction: SIMD3<Float>, planeY: Float) -> SIMD3<Float>? {
    
    let direction = simd_normalize(direction)

    // Special case handling: Check if the ray is horizontal as well.
    if direction.y == 0 {
        if rayOrigin.y == planeY {
            // The ray is horizontal and on the plane, thus all points on the ray intersect with the plane.
            // Therefore we simply return the ray origin.
            return rayOrigin
        } else {
            // The ray is parallel to the plane and never intersects.
            return nil
        }
    }
    
    // The distance from the ray's origin to the intersection point on the plane is:
    //   (pointOnPlane - rayOrigin) dot planeNormal
    //  --------------------------------------------
    //          direction dot planeNormal
    
    // Since we know that horizontal planes have normal (0, 1, 0), we can simplify this to:
    let dist = (planeY - rayOrigin.y) / direction.y

    // Do not return intersections behind the ray's origin.
    if dist < 0 {
        return nil
    }
    
    // Return the intersection point.
    return rayOrigin + (direction * dist)
}



@available(iOS 12.0, *)
extension ARPlaneAnchor.Classification {
    var description: String {
        switch self {
        case .wall:
            return "Wall"
        case .floor:
            return "Floor"
        case .ceiling:
            return "Ceiling"
        case .table:
            return "Table"
        case .seat:
            return "Seat"
        case .none(.unknown):
            return "Unknown"
        default:
            return ""
        }
    }
}

extension SCNNode {
    func centerAlign() {
        let (min, max) = boundingBox
        let extents = float3(max) - float3(min)
        simdPivot = float4x4(translation: ((extents / 2) + float3(min)))
    }
}

extension float4x4 {
    init(translation vector: float3) {
        self.init(float4(1, 0, 0, 0),
                  float4(0, 1, 0, 0),
                  float4(0, 0, 1, 0),
                  float4(vector.x, vector.y, vector.z, 1))
    }
}
