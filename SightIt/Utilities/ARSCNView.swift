//
//  ARSCNView.swift
//  SightIt
//
//  Created by Khang Vu on 7/26/20.
//  Copyright © 2020 SightIt. All rights reserved.
//

import ARKit

extension ARSCNView {
    
    // MARK: - Types
    
    /// A ray to use for hit testing
    struct HitTestRay {
        /// the origin (x, y, z) of the ray
        let origin: SIMD3<Float>
        /// The direction of the ray
        let direction: SIMD3<Float>
    }
    
    /// A hit test resulting from intersecting a ray with tracked feature points
    struct FeatureHitTestResult {
        /// The position computed by intersecting the ray with the feature points
        let position: SIMD3<Float>
        /// Distance along the ray where the hit was genereated
        let distanceToRayOrigin: Float
        /// the location of the feature hit
        let featureHit: SIMD3<Float>
        /// The distance of the feature to the hit result
        let featureDistanceToHitResult: Float
    }
    
    // MARK: - Initial Setup
    
    /// Setup the ARSCNView by tweaking some camera settings
    func setup() {
        antialiasingMode = .multisampling4X
        automaticallyUpdatesLighting = false
        
        preferredFramesPerSecond = 60
        contentScaleFactor = 1.3
        
        if let camera = pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
            camera.exposureOffset = -1
            camera.minimumExposure = -1
            camera.maximumExposure = 3
        }
    }
    
    /// Unprojects a point from the 2D pixel coordinate system of the renderer to the 3D
    /// world coordinate system of the scene.  This modifies the typical behavior by
    /// allowing for an override of the frame transform so that the unprojection can be
    /// done with respect to past frames.
    /// - Parameters:
    ///   - point: the point to unproject (if z is 0 use the near clipping plane, if z
    ///       is 1 use the far clipping plane)
    ///   - overrideFrameTransform: an optional frame transform to use instead of the
    ///       current frame transform
    /// - Returns: the 3D coordinates of the pixel location
    func unprojectPoint(_ point: SIMD3<Float>, overrideFrameTransform: matrix_float4x4? = nil) -> SIMD3<Float> {
        if let currentFrame = self.session.currentFrame {
            let cameraTransformToUse: matrix_float4x4
            if let overrideFrameTransform = overrideFrameTransform {
                cameraTransformToUse = overrideFrameTransform
            } else {
                return SIMD3<Float>(self.unprojectPoint(SCNVector3(point)))
            }
            
            // we first compute the 3d point in world coordinates that would make sense if the pixel location was for the currentFrame
            let worldRelativeToCurrentScene =  SIMD3<Float>(self.unprojectPoint(SCNVector3(point)))
            // we now represent this 3d point to make it easy to transform later
            let worldRelativeToCurrentSceneAsMatrix = SCNMatrix4MakeTranslation(worldRelativeToCurrentScene.x, worldRelativeToCurrentScene.y, worldRelativeToCurrentScene.z)
            // timeTransform contains a matrix that maps to the camera coordinate system of currentFrame and then reprojects into the world
            // SCNMatrix4Mult is used for making compound transforms, therefore it does B*A rathern than A*B
            let timeTransform = SCNMatrix4Mult(SCNMatrix4.init(currentFrame.camera.transform.inverse), SCNMatrix4.init(cameraTransformToUse))
            let transformedPointAsMatrix = SCNMatrix4Mult(worldRelativeToCurrentSceneAsMatrix, timeTransform)
            
            return SIMD3<Float>(x: transformedPointAsMatrix.m41, y: transformedPointAsMatrix.m42, z: transformedPointAsMatrix.m43)
        } else {
            return SIMD3<Float>()
        }
    }
    
    // MARK: - Hit Tests
    
    /// Create a hit test ray suitable for intersecting with various 3D structures such
    /// as planes and feature points.
    ///
    /// - Parameters:
    ///   - point: the point (2D) to use for creating the ray
    ///   - overrideFrameTransform: if set, use the specified frame transform instead
    ///        of the one of the current frame.
    /// - Returns: a hit test ray (consisting of an origin and a direction in 3D).
    func hitTestRayFromScreenPos(_ point: CGPoint,                              overrideFrameTransform: matrix_float4x4? = nil) -> HitTestRay? {
        let cameraPos: SIMD3<Float>

        if let overrideFrameTransform = overrideFrameTransform {
            cameraPos = overrideFrameTransform.translation
        } else {
            guard let frame = self.session.currentFrame else {
                return nil
            }
            cameraPos = frame.camera.transform.translation
        }

        // Note: z: 1.0 will unproject() the screen position to the far clipping plane.
        let positionVec = SIMD3<Float>(x: Float(point.x), y: Float(point.y), z: 1.0)
        let screenPosOnFarClippingPlane = self.unprojectPoint(positionVec, overrideFrameTransform: overrideFrameTransform)
        
        let rayDirection = simd_normalize(screenPosOnFarClippingPlane - cameraPos)
        return HitTestRay(origin: cameraPos, direction: rayDirection)
    }
    
    /// Perform a hit test with an infinite horizontal plane (e.g., the ground plane)
    ///
    /// - Parameters:
    ///   - point: the point to test for intersection with the plane
    ///   - pointOnPlane: the position of the plane (only the y coordinate is used since
    ///       we assume the plane is horizontal and infinite)
    /// - Returns: the results of the hit test
    func hitTestWithInfiniteHorizontalPlane(_ point: CGPoint, _ pointOnPlane: SIMD3<Float>) -> SIMD3<Float>? {
        guard let ray = hitTestRayFromScreenPos(point) else {
            return nil
        }
        
        // Do not intersect with planes above the camera or if the ray is almost parallel to the plane.
        if ray.direction.y > -0.03 {
            return nil
        }
        
        // Return the intersection of a ray from the camera through the screen position with a horizontal plane
        // at height (Y axis).
        return rayIntersectionWithHorizontalPlane(rayOrigin: ray.origin, direction: ray.direction, planeY: pointOnPlane.y)
    }
    
    /// Perform a hit test with the feature points (yellow dots) tracked frame to frame
    ///
    /// - Parameters:
    ///   - point: the 2D pixel location
    ///   - coneOpeningAngleInDegrees: the cone in which to search for feature points
    ///   - minDistance: the minimum distance to consider a feature point for a match
    ///   - maxDistance: the maximum distance to consider a feature point for a match
    ///   - maxResults: the maximum number of potential hits to return
    /// - Returns: the results of the hit test as a list of potential feature point hits
    func hitTestWithFeatures(_ point: CGPoint, coneOpeningAngleInDegrees: Float,
                             minDistance: Float = 0,
                             maxDistance: Float = Float.greatestFiniteMagnitude,
                             maxResults: Int = 1) -> [FeatureHitTestResult] {
        var results = [FeatureHitTestResult]()
        
        guard let features = self.session.currentFrame?.rawFeaturePoints else {
            return results
        }
        
        guard let ray = hitTestRayFromScreenPos(point) else {
            return results
        }
        
        let maxAngleInDeg = min(coneOpeningAngleInDegrees, 360) / 2
        let maxAngle = (maxAngleInDeg / 180) * .pi
        
        let points = features.points
        
        for featurePos in points {
            let originToFeature = featurePos - ray.origin
            
            let crossProduct = simd_cross(originToFeature, ray.direction)
            let featureDistanceFromResult = simd_length(crossProduct)
            
            let hitTestResult = ray.origin + (ray.direction * simd_dot(ray.direction, originToFeature))
            let hitTestResultDistance = simd_length(hitTestResult - ray.origin)
            
            if hitTestResultDistance < minDistance || hitTestResultDistance > maxDistance {
                // Skip this feature - it is too close or too far away.
                continue
            }
            
            let originToFeatureNormalized = simd_normalize(originToFeature)
            let angleBetweenRayAndFeature = acos(simd_dot(ray.direction, originToFeatureNormalized))
            
            if angleBetweenRayAndFeature > maxAngle {
                // Skip this feature - is is outside of the hit test cone.
                continue
            }
            
            // All tests passed: Add the hit against this feature to the results.
            results.append(FeatureHitTestResult(position: hitTestResult,
                                                distanceToRayOrigin: hitTestResultDistance,
                                                featureHit: featurePos,
                                                featureDistanceToHitResult: featureDistanceFromResult))
        }
        
        // Sort the results by feature distance to the ray.
        results = results.sorted(by: { (first, second) -> Bool in
            return first.distanceToRayOrigin < second.distanceToRayOrigin
        })
        
        // Cap the list to maxResults.
        var cappedResults = [FeatureHitTestResult]()
        var i = 0
        while i < maxResults && i < results.count {
            cappedResults.append(results[i])
            i += 1
        }
        
        return cappedResults
    }
    
    /// Perform a hit test on the scene with the specified pixel coordinate
    ///
    /// - Parameter point: the pixel coordinate (2D)
    /// - Returns: an array of potential feature point hits
    func hitTestWithFeatures(_ point: CGPoint) -> [FeatureHitTestResult] {
        
        var results = [FeatureHitTestResult]()
        
        guard let ray = hitTestRayFromScreenPos(point) else {
            return results
        }
        
        if let result = self.hitTestFromOrigin(origin: ray.origin, direction: ray.direction) {
            results.append(result)
        }
        
        return results
    }
    
    /// Hit test from a different origin (not necessarily the current position)
    ///
    /// - Parameters:
    ///   - origin: the origin to start from
    ///   - direction: the direction to search in
    /// - Returns: any feature points that are potential hits
    func hitTestFromOrigin(origin: SIMD3<Float>, direction: SIMD3<Float>) -> FeatureHitTestResult? {
        
        guard let features = self.session.currentFrame?.rawFeaturePoints else {
            return nil
        }
        
        let points = features.points
        
        // Determine the point from the whole point cloud which is closest to the hit test ray.
        var closestFeaturePoint = origin
        var minDistance = Float.greatestFiniteMagnitude
        
        for featurePos in points {
            let originVector = origin - featurePos
            let crossProduct = simd_cross(originVector, direction)
            let featureDistanceFromResult = simd_length(crossProduct)
            
            if featureDistanceFromResult < minDistance {
                closestFeaturePoint = featurePos
                minDistance = featureDistanceFromResult
            }
        }
        
        // Compute the point along the ray that is closest to the selected feature.
        let originToFeature = closestFeaturePoint - origin
        let hitTestResult = origin + (direction * simd_dot(direction, originToFeature))
        let hitTestResultDistance = simd_length(hitTestResult - origin)
        
        return FeatureHitTestResult(position: hitTestResult,
                                    distanceToRayOrigin: hitTestResultDistance,
                                    featureHit: closestFeaturePoint,
                                    featureDistanceToHitResult: minDistance)
    }
    
}
