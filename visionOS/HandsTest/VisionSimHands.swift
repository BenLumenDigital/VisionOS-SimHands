//
//  VisionSimHands.swift
//  HandsTest
//
//  Created by Ben Harraway on 17/12/2023.
//

import Foundation
import SwiftUI
import RealityKit
import RealityKitContent

// These are named the same as HandAnchor from RealityKit / VisionOS
enum HandPart {
    case littleFingerTip
    case littleFingerIntermediateTip
    case littleFingerIntermediateBase
    case littleFingerKnuckle
    case ringFingerTip
    case ringFingerIntermediateTip
    case ringFingerIntermediateBase
    case ringFingerKnuckle
    case middleFingerTip
    case middleFingerIntermediateTip
    case middleFingerIntermediateBase
    case middleFingerKnuckle
    case indexFingerTip
    case indexFingerIntermediateTip
    case indexFingerIntermediateBase
    case indexFingerKnuckle
    case thumbTip
    case thumbIntermediateTip
    case thumbIntermediateBase
    case thumbKnuckle
    case Wrist
    case Unsure
}

struct JointPosition {
    var x : Double = 0.0
    var y : Double = 0.0
    var z : Double = 0.0
    var handPart: HandPart
    
    init?(jointIndex : Int) {
        switch jointIndex {
        case 0:
            handPart = .Wrist
        case 1:
            handPart = .thumbKnuckle
        case 2:
            handPart = .thumbIntermediateBase
        case 3:
            handPart = .thumbIntermediateTip
        case 4:
            handPart = .thumbTip
            
        case 5:
            handPart = .indexFingerKnuckle
        case 6:
            handPart = .indexFingerIntermediateBase
        case 7:
            handPart = .indexFingerIntermediateTip
        case 8:
            handPart = .indexFingerTip
            
        case 9:
            handPart = .middleFingerKnuckle
        case 10:
            handPart = .middleFingerIntermediateBase
        case 11:
            handPart = .middleFingerIntermediateTip
        case 12:
            handPart = .middleFingerTip
            
        case 13:
            handPart = .ringFingerKnuckle
        case 14:
            handPart = .ringFingerIntermediateBase
        case 15:
            handPart = .ringFingerIntermediateTip
        case 16:
            handPart = .ringFingerTip
            
        case 17:
            handPart = .littleFingerKnuckle
        case 18:
            handPart = .littleFingerIntermediateBase
        case 19:
            handPart = .littleFingerIntermediateTip
        case 20:
            handPart = .littleFingerTip
            
        default:
            handPart = .Unsure
        }
    }
}

class Hand {
    var joints:Array<JointPosition> = []
    var models:Array<ModelEntity> = []
}

class SimulatorHandTrackingProvider {
    
    let bonjour = BonjourSession(configuration: .default)
    
    var leftHand = Hand()
    var rightHand = Hand()
    
    public func start() {
        print("Starting Sim Hands")
        
        // Start the Bonjour service which looks for data from the macOS Helper App
        bonjour.start()
        bonjour.onReceive = { data, peer in
            do {
                let handJointData: AnyObject? = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as AnyObject
                
                self.parseJointDataJson(anyObj: handJointData!, leftHand: self.leftHand, rightHand: self.rightHand)
                
            } catch {
                
            }
        }
    }
    
    // Add Hands to UI
    // You don't need to do this, but they look nice!
    public func addHands(_ content: RealityViewContent, _ anchor: AnchorEntity) {
        // Create Hand Dots
        // The hand API gives us 21 positions per hand
        // So, create 21 models per hand to visualize the joints
        for _ in 0...21 {
            let handLeftDot = getHandJointSphere(location: SIMD3<Float>(x: 0.0, y: 0.0, z: 0.0), color: .blue, radius: 0.03)
            handLeftDot.setParent(anchor)
            leftHand.models.append(handLeftDot)
            
            let handRightDot = getHandJointSphere(location: SIMD3<Float>(x: 0.0, y: 0.0, z: 0.0), color: .green, radius: 0.03)
            handRightDot.setParent(anchor)
            rightHand.models.append(handRightDot)
        }
    }
    
    func getHandJointSphere(location: SIMD3<Float>, color: SimpleMaterial.Color, radius: Float) -> ModelEntity {
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius))
        sphere.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
        sphere.position = location
            
        sphere.physicsBody = PhysicsBodyComponent(massProperties: .init(mass: 0), material: .generate(friction: 0.5, restitution: 0.1), mode: .dynamic)
        
        let collisionShape = ShapeResource.generateSphere(radius: 0.06)
        let collisionComp = CollisionComponent(shapes: [collisionShape])
        sphere.components.set(collisionComp)
        
        return sphere
    }

    private func parseJointDataJson(anyObj:AnyObject, leftHand: Hand, rightHand: Hand) {
         if anyObj is Array<AnyObject> {

             DispatchQueue.main.async {
                 // Parse incoming joint data into Joints
                 
                 // Remove all old stale data
                 leftHand.joints.removeAll()
                 rightHand.joints.removeAll()
                 
                 for model in leftHand.models {
                     model.isEnabled = false
                 }
                 for model in rightHand.models {
                     model.isEnabled = false
                 }
                 
                 // Loop data and redraw joints
                 var handIndex = 0
                 for json in anyObj as! Array<AnyObject>{
                     let joints = json as? Array<NSDictionary>
                     var jointIndex = 0
                     for joint in joints! {
                         
                         var jointPosition : JointPosition = JointPosition(jointIndex: jointIndex)!
                         jointPosition.x = (joint["x"] as AnyObject? as? Double) ?? 0
                         jointPosition.y = (joint["y"] as AnyObject? as? Double) ?? 0
                         jointPosition.z = (joint["z"] as AnyObject? as? Double) ?? 0
                         
                         if (handIndex == 0) {
                             leftHand.joints.append(jointPosition)
                             
                             if (!leftHand.models.isEmpty) {
                                 if (jointIndex < leftHand.models.count) {
                                     leftHand.models[jointIndex].isEnabled = true
                                     leftHand.models[jointIndex].position.x = 0.5 - Float(jointPosition.x)
                                     leftHand.models[jointIndex].position.y = 0.5 - Float(jointPosition.y)
                                     leftHand.models[jointIndex].position.z = (0.5 + Float(jointPosition.z)) - 1.0
                                 } else {
                                     leftHand.models[jointIndex].isEnabled = false
                                 }
                             }
                             
                         } else if (handIndex == 1) {
                             rightHand.joints.append(jointPosition)
                             
                             if (!rightHand.models.isEmpty) {
                                 if (jointIndex < rightHand.models.count) {
                                     rightHand.models[jointIndex].isEnabled = true
                                     rightHand.models[jointIndex].position.x = 0.5 - Float(jointPosition.x)
                                     rightHand.models[jointIndex].position.y = 0.5 - Float(jointPosition.y)
                                     rightHand.models[jointIndex].position.z = (0.5 + Float(jointPosition.z)) - 1.0
                                 } else {
                                     rightHand.models[jointIndex].isEnabled = false
                                 }
                             }
                         }
                         
                         jointIndex = jointIndex + 1
                     }
                     
                     handIndex = handIndex + 1
                 }
             }
        }
    }
}
