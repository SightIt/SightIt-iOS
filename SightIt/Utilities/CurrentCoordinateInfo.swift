//
//  CurrentCoordinateInfo.swift
//  SightIt
//
//  Created by Khang Vu on 7/28/20.
//  Copyright © 2020 SightIt. All rights reserved.
//

import VectorMath

/// A struct that holds the current coordinate info (e.g., to represent the pose of the camera)
public struct CurrentCoordinateInfo {
    /// the location
    public var location: LocationInfo
    /// the transformation
    public var transformMatrix: Matrix3 = Matrix3.identity
    
    /// Initialize a new CurrentCoordinateInfo struct
    ///
    /// - Parameters:
    ///   - location: the location of the coordinate info
    ///   - transMatrix: the transformation matrix to the coordinate info
    public init(_ location: LocationInfo, transMatrix: Matrix3) {
        self.location = location
        self.transformMatrix = transMatrix
    }
    
    /// Initialize a new CurrentCoordinateInfo struct
    ///
    /// - Parameters:
    ///   - location: the location of the coordinate info
    public init(_ location: LocationInfo) {
        self.location = location
    }
}

/// Struct to store position information and yaw
public struct LocationInfo {
    /// the x position
    public var x: Float
    /// the y position
    public var y: Float
    /// the z position
    public var z: Float
    /// the yaw (rotation about the axis of gravity)
    public var yaw: Float
    
    /// Initialize a LocationInfo
    ///
    /// - Parameters:
    ///   - x: x coordinate
    ///   - y: y coordinate
    ///   - z: z coordinate
    ///   - yaw: yaw (angle about the axis of gravity)
    public init(x: Float, y: Float, z: Float, yaw: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.yaw = yaw
    }
}
