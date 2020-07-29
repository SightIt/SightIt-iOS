//
//  JobInfo.swift
//  SightIt
//
//  Created by Khang Vu on 7/28/20.
//  Copyright © 2020 SightIt. All rights reserved.
//

import ARKit

/// The various statuses that a job can have.
///
/// - waitingForInitialResponse: The job has been posted and is waiting for a response
/// - waitingForPosition: The job is waiting to be positioned (TODO: currently unused and potentially not needed)
/// - waitingForAdditionalResponse: The job was answered by someone, but the coordinate could not be mapped to 3D
/// - placed: the job has been localized in 3D
/// - failed: the job could not be localized in 3D and we are not going to try anymore to do so
enum JobStatus {
    /// - waitingForInitialResponse: The job has been posted and is waiting for a response
    case waitingForInitialResponse
    /// - waitingForPosition: The job is waiting to be positioned (TODO: currently unused and potentially not needed)
    case waitingForPosition
    /// - waitingForAdditionalResponse: The job was answered by someone, but the coordinate could not be mapped to 3D
    case waitingForAdditionalResponse
    /// - placed: the job has been localized in 3D
    case placed
    /// - failed: the job could not be localized in 3D and we are not going to try anymore to do so
    case failed
}

/// Tracks a job's data.
class JobInfo {
    /// A dictionary that maps from image UUIDs to camera transforms
    var cameraTransforms : [String: matrix_float4x4]
    /// A scene image snapshot used for dimension checking... TODO: Just store bounds
    var sceneImage : UIImage
    /// The object we are attempting to find
    var objectToFind : String
    /// The status of the job
    var status : JobStatus = JobStatus.waitingForInitialResponse
    
    /// Initialize a new job info
    ///
    /// - Parameters:
    ///   - cameraTransforms: the camera transforms (dictionary mapping image UUIDs to transformation matrices)
    ///   - sceneImage: a scene snapshot (for dimensionality checking)
    ///   - objectToFind: the object to search for
    init(cameraTransforms: [String: matrix_float4x4], sceneImage: UIImage, objectToFind: String) {
        self.cameraTransforms = cameraTransforms
        self.sceneImage = sceneImage
        self.objectToFind = objectToFind
    }
}
