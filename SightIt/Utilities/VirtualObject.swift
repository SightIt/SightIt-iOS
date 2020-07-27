//
//  VirtualObject.swift
//  SightIt
//
//  Created by Khang Vu on 7/26/20.
//  Copyright © 2020 SightIt. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

/// Tracks a virtual object placed in the scene
class VirtualObject: SCNNode {
    /// The label of the virtual object (this is the same as what the user indicated when requesting the localization job)
    let objectToFind: String
    /// The scene node for the virtual object (currently this is just a cube).
    let cubeNode: SCNNode
    
    /// Initialize an object
    ///
    /// - Parameter objectToFind: the object the user is requesting to find
    init(objectToFind: String) {
        self.objectToFind = objectToFind
        
        cubeNode = SCNNode(geometry: SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0))
        cubeNode.position = SCNVector3(0, 0, 0.0)
        
        super.init()
        
        self.addChildNode(cubeNode)
        let objectText = SCNText(string: objectToFind, extrusionDepth: 1.0)
        objectText.font = UIFont (name: "Arial", size: 48)
        objectText.firstMaterial!.diffuse.contents = UIColor.green
        let textNode = SCNNode(geometry: objectText)
        textNode.position = SCNVector3(x: 0.0, y: 0.15, z: 0.0)
        textNode.scale = SCNVector3(x: 0.002, y: 0.002, z: 0.002)
        cubeNode.addChildNode(textNode)
        center(node: textNode)
    }
    
    /// Center a scene node
    ///
    /// - Parameter node: the node to center
    func center(node: SCNNode) {
        let (min, max) = node.boundingBox
        
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        node.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
    }
    
    /// This has not been implemented
    ///
    /// - Parameter aDecoder: NSCoder
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension VirtualObject {
    
    /// Checks of a particular node is part of a virtual object
    ///
    /// - Parameter node: the scene node to test for membership
    /// - Returns: the virtual object (if the node is part of a virtual object), nil otherwise
    static func isNodePartOfVirtualObject(_ node: SCNNode) -> VirtualObject? {
        if let virtualObjectRoot = node as? VirtualObject {
            return virtualObjectRoot
        }
        
        if node.parent != nil {
            return isNodePartOfVirtualObject(node.parent!)
        }
        
        return nil
    }
    
}
