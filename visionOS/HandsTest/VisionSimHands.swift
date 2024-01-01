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
    case wrist
    case Unsure
}

enum HandPose {
    case unknown
    case openPalm
    case fist
    case pointing
    case peaceSign
    case flippingBird
}

struct Joint {
    var position: SIMD3<Double> = SIMD3(x: 0, y: 0, z: 0) // World Position
    var handPart: HandPart
    
    init?(jointIndex : Int) {
        switch jointIndex {
        case 0:
            handPart = .wrist
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
    var chirality: String = "unsure"            //TODO - Chirality, pass Left or Right hand from MediaPipes
    
    var joints: Array<Joint> = []               // An array of Joints, their World positions, and their type
    var models: Array<ModelEntity> = []         // An array of ModelEntity objects representing the joints in 3D visual space
    var handPose: HandPose = .unknown           // The current Pose the hand is in
    
    var normaliseDistance = 1.0                 // Calculation to let us normalise joint distances independantly of Z distance
    let distanceForJointsClose = 0.31
    let distanceForJointsApart = 0.75
    
    var normaliseRotation: SIMD3<Double>?       // Direction the hand is pointing in
}

class SimulatorHandTrackingProvider: ObservableObject {
    
    let bonjour = BonjourSession(configuration: .default)
    
    @Published var leftHand = Hand()
    @Published var rightHand = Hand()
    @Published var timestamp: Double = 0
    
    @State private var subs: [EventSubscription] = []   // For collision events
    
    public func start() {
        print("Starting Sim Hands")
        
        // Create some empty Joints, we will populate them when data arrives
        // The hand API gives us 21 positions per hand
        for jointIndex in 0...21 {
            let leftJoint : Joint = Joint(jointIndex: jointIndex)!
            let rightJoint : Joint = Joint(jointIndex: jointIndex)!
            
            leftHand.joints.append(leftJoint)
            rightHand.joints.append(rightJoint)
        }
        
        // Start the Bonjour service which looks for data from the macOS Helper App
        bonjour.start()
        bonjour.onReceive = { data, peer in
            do {
                let handJointData: AnyObject? = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as AnyObject
                
                self.parseJointDataJson(anyObj: handJointData!, leftHand: self.leftHand, rightHand: self.rightHand)
                
                self.checkHandPose()
                
            } catch {
                print("Oh no, bonjour or data error in VisionSimHands")
            }
        }
    }
    
    // Add Hands to UI
    // You don't need to do this, but they look nice!
    public func addHands(_ content: RealityViewContent, _ anchor: AnchorEntity) {
        // Create Hand Dots
        // The hand API gives us 21 positions per hand
        // So, create 21 models per hand to visualize the joints
        for index in 0...21 {
            let handLeftDot = getHandJointSphere(location: SIMD3<Float>(x: 0.0, y: 0.0, z: 0.0), color: .blue, radius: 0.03)
            handLeftDot.setParent(anchor)
            handLeftDot.name = "Left - Joint \(index)"
            leftHand.models.append(handLeftDot)
            
            let handRightDot = getHandJointSphere(location: SIMD3<Float>(x: 0.0, y: 0.0, z: 0.0), color: .green, radius: 0.03)
            handRightDot.setParent(anchor)
            handRightDot.name = "Right Hand - Joint \(index)"
            rightHand.models.append(handRightDot)
            
            let eventLeft = content.subscribe(to: CollisionEvents.Began.self, on: handLeftDot) { ce in
                print("Left Collision between \(ce.entityA.name) and \(ce.entityB.name) has occured")
            }
            
            let eventRight = content.subscribe(to: CollisionEvents.Began.self, on: handRightDot) { ce in
                print("Right Collision between \(ce.entityA.name) and \(ce.entityB.name) has occured")
            }
            
            Task {
                subs.append(eventLeft)
                subs.append(eventRight)
            }
        }
    }
    
    func getHandJointSphere(location: SIMD3<Float>, color: SimpleMaterial.Color, radius: Float) -> ModelEntity {
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius))
        sphere.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
        sphere.position = location
            
        sphere.physicsBody = PhysicsBodyComponent(massProperties: .init(mass: 0), material: .generate(friction: 0.5, restitution: 0.1), mode: .dynamic)
        
        let collisionShape = ShapeResource.generateSphere(radius: radius)
        let collisionComp = CollisionComponent(shapes: [collisionShape])
        sphere.components.set(collisionComp)
        
        return sphere
    }

    // Parse incoming JSON data into Swift Hand objects
    // Also, move the 3D spheres that represent Joints if there are any
    private func parseJointDataJson(anyObj:AnyObject, leftHand: Hand, rightHand: Hand) {
        let landmarks = anyObj["landmarks"]
        let handednesses = anyObj["handednesses"]
        
        var firstHand: String?
        var secondHand: String?
        
        // Get Chirality / Handednesses / Left/Right hand
        // Call me crazy, but I'm certain the MediaPipes reports the hands incorrectly
        // It tells you Left is Right and Right is Left!
        for json in handednesses as! Array<AnyObject>{
            let handsInfo = json as! Array<NSDictionary>
            
            for handInfo in handsInfo {
                var handSide = handInfo["displayName"] as! String
                if (handSide == "Left") {
                    handSide = "Right"
                } else if (handSide == "Right") {
                    handSide = "Left"
                }
                
                if (firstHand == nil) {
                    firstHand = handSide
                } else {
                    secondHand = handSide
                }
            }
        }
        
         if landmarks is Array<AnyObject> {

             DispatchQueue.main.async {
                 // Parse incoming joint data into Joints
                 
                 for model in leftHand.models {
                     model.isEnabled = false
                 }
                 for model in rightHand.models {
                     model.isEnabled = false
                 }
                 
                 // Loop data and redraw joints
                 var handIndex = 0
                 for json in landmarks as! Array<AnyObject>{
                     let joints = json as? Array<NSDictionary>
                     var jointIndex = 0
                     for jointData in joints! {
                                              
                         // Data feed from Google MediaPipes is xyz in 0-1 range
                         // The value depicts the position in the canvas frame
                         if (handIndex == 0) {
                             var joint: Joint = leftHand.joints[jointIndex]
                             joint.position = SIMD3((jointData["x"] as AnyObject? as? Double) ?? 0,
                                                    (jointData["y"] as AnyObject? as? Double) ?? 0,
                                                    (jointData["z"] as AnyObject? as? Double) ?? 0)
                             
                             leftHand.joints[jointIndex] = joint
                             
                             leftHand.chirality = firstHand ?? "unknown"
                             leftHand.handPose = .unknown
                             
                             if (!leftHand.models.isEmpty) {
                                 if (jointIndex < leftHand.models.count) {
                                     // Map MediaPipe position to world space
                                     leftHand.models[jointIndex].position = SIMD3(0.5 - Float(joint.position.x),
                                                                                  0.5 - Float(joint.position.y),
                                                                                  (0.5 + Float(joint.position.z)) - 1.0)
                                     leftHand.models[jointIndex].isEnabled = true
                                 } else {
                                     leftHand.models[jointIndex].isEnabled = false
                                 }
                             }
                             
                         } else if (handIndex == 1) {
                             var joint: Joint = rightHand.joints[jointIndex]
                             joint.position = SIMD3((jointData["x"] as AnyObject? as? Double) ?? 0,
                                                    (jointData["y"] as AnyObject? as? Double) ?? 0,
                                                    (jointData["z"] as AnyObject? as? Double) ?? 0)
                             
                             rightHand.joints[jointIndex] = joint
                             
                             rightHand.chirality = secondHand ?? "unknown"
                             rightHand.handPose = .unknown
                             
                             if (!rightHand.models.isEmpty) {
                                 if (jointIndex < rightHand.models.count) {
                                     // Map MediaPipe position to world space
                                     rightHand.models[jointIndex].position = SIMD3(0.5 - Float(joint.position.x),
                                                                                  0.5 - Float(joint.position.y),
                                                                                  (0.5 + Float(joint.position.z)) - 1.0)
                                     rightHand.models[jointIndex].isEnabled = true
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
    
    // Check for any Hand Poses we might be looking for
    func checkHandPose() {
        
        for hand in [leftHand, rightHand] {
                
            // Normalise hand joint positions locally to the hand
            // Not sure the best way to do this, but I've chosen to
            // use the distance between the Wrist and Middle Finger Knuckle joint
            // I figured this distance changes the least during different hand poses.
            // It also gives us a pretty good idea of the hands orientation.
            if let wristJoint = hand.joints.filter({ $0.handPart == .wrist}).first,
               let middleFingerKnuckle = hand.joints.filter({ $0.handPart == .middleFingerKnuckle}).first
            {
                let distanceWristToMiddleFingerKnuckle = distance(wristJoint.position, middleFingerKnuckle.position)

                // Warning Magic number coming up, yikes!  This 2.0 is an average of the distance
                // of wrist->thumbKnuckle compared to wrist->middleFingerTip when extended.
                // This should give us the maximum possible joint distance
                let approximateWristToMiddleFingerTip = distanceWristToMiddleFingerKnuckle * 2.0
                let normaliseToHandDelta = 1.0 / approximateWristToMiddleFingerTip
                
                hand.normaliseDistance = normaliseToHandDelta
                
                // Get the general rotational pose of the hand
                hand.normaliseRotation = normalize(cross(wristJoint.position, middleFingerKnuckle.position))
            }
            
            if checkPose_PeaceSign(hand: hand) {
                print(hand.chirality, "peace")
                
            } else if checkPose_Pointing(hand: hand) {
                print(hand.chirality, "pointing")

            } else if checkPose_FlipBird(hand: hand) {
                print(hand.chirality, "flipping the bird")

            } else if checkPose_Fist(hand: hand) {
                print(hand.chirality, "fist")

            } else if checkPose_OpenPalm(hand: hand) {
                print(hand.chirality, "open palm")
                
            }
        }
    }
    
    // Check for a Fist:
    // Distance between little finger tip and wrist is small
    // And make sure finger tips are all next to each other
    func checkPose_Fist(hand: Hand) -> Bool {
        if let wristJoint = hand.joints.filter({ $0.handPart == .wrist}).first,
           let littleFingerTip = hand.joints.filter({ $0.handPart == .littleFingerTip}).first,
           let ringFingerTip = hand.joints.filter({ $0.handPart == .ringFingerTip}).first,
           let indexFingerTip = hand.joints.filter({ $0.handPart == .indexFingerTip}).first,
           let middleFingerTip = hand.joints.filter({ $0.handPart == .middleFingerTip}).first {
            
            let distanceBetweenJointsLittle = distance(wristJoint.position, littleFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsRing = distance(littleFingerTip.position, ringFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsIndex = distance(middleFingerTip.position, indexFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsMiddle = distance(ringFingerTip.position, middleFingerTip.position) * hand.normaliseDistance
            
            if (distanceBetweenJointsLittle <= hand.distanceForJointsClose &&
                distanceBetweenJointsRing <= hand.distanceForJointsClose &&
                distanceBetweenJointsIndex <= hand.distanceForJointsClose &&
                distanceBetweenJointsMiddle <= hand.distanceForJointsClose) {
                hand.handPose = .fist
                return true
            }
        }
        
        return false
    }
    
    // Check for Pointing:
    // Check all fingers are down (like in Fist)
    // But ensure Index finger is up
    func checkPose_Pointing(hand: Hand) -> Bool {
        if let wristJoint = hand.joints.filter({ $0.handPart == .wrist}).first,
           let littleFingerTip = hand.joints.filter({ $0.handPart == .littleFingerTip}).first,
           let ringFingerTip = hand.joints.filter({ $0.handPart == .ringFingerTip}).first,
           let indexFingerTip = hand.joints.filter({ $0.handPart == .indexFingerTip}).first,
           let middleFingerTip = hand.joints.filter({ $0.handPart == .middleFingerTip}).first {
            
            let distanceBetweenJointsLittle = distance(wristJoint.position, littleFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsRing = distance(littleFingerTip.position, ringFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsIndex = distance(wristJoint.position, indexFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsMiddle = distance(ringFingerTip.position, middleFingerTip.position) * hand.normaliseDistance
                        
            if (distanceBetweenJointsIndex >= hand.distanceForJointsApart &&
                distanceBetweenJointsLittle <= hand.distanceForJointsClose &&
                distanceBetweenJointsRing <= hand.distanceForJointsClose &&
                distanceBetweenJointsMiddle <= hand.distanceForJointsClose) {
                    hand.handPose = .pointing
                    return true
            }
        }
        
        return false
    }
    
    // Check for Flipping the bird. First check for Fist, then ensure index finger is extended
    // Check all fingers are down (like in Fist)
    // But ensure Middle finger is up
    func checkPose_FlipBird(hand: Hand) -> Bool {
        if let wristJoint = hand.joints.filter({ $0.handPart == .wrist}).first,
           let littleFingerTip = hand.joints.filter({ $0.handPart == .littleFingerTip}).first,
           let ringFingerTip = hand.joints.filter({ $0.handPart == .ringFingerTip}).first,
           let indexFingerTip = hand.joints.filter({ $0.handPart == .indexFingerTip}).first,
           let middleFingerTip = hand.joints.filter({ $0.handPart == .middleFingerTip}).first {
            
            let distanceBetweenJointsLittle = distance(wristJoint.position, littleFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsRing = distance(littleFingerTip.position, ringFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsIndex = distance(littleFingerTip.position, indexFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsMiddle = distance(wristJoint.position, middleFingerTip.position) * hand.normaliseDistance
                        
            if (distanceBetweenJointsMiddle >= hand.distanceForJointsApart &&
                distanceBetweenJointsLittle <= hand.distanceForJointsClose &&
                distanceBetweenJointsRing <= hand.distanceForJointsClose &&
                distanceBetweenJointsIndex <= hand.distanceForJointsClose) {
                    hand.handPose = .flippingBird
                    return true
            }
        }
        
        return false
    }
    
    // Check for Peace Sign - Index and Middle fingers up and Ring and Little fingers down
    func checkPose_PeaceSign(hand: Hand) -> Bool {
        if let wristJoint = hand.joints.filter({ $0.handPart == .wrist}).first,
           let littleFingerTip = hand.joints.filter({ $0.handPart == .littleFingerTip}).first,
           let ringFingerTip = hand.joints.filter({ $0.handPart == .ringFingerTip}).first,
           let indexFingerTip = hand.joints.filter({ $0.handPart == .indexFingerTip}).first,
           let middleFingerTip = hand.joints.filter({ $0.handPart == .middleFingerTip}).first {
            
            let distanceBetweenJointsLittle = distance(wristJoint.position, littleFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsRing = distance(wristJoint.position, ringFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsIndex = distance(wristJoint.position, indexFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsMiddle = distance(wristJoint.position, middleFingerTip.position) * hand.normaliseDistance
                        
            if (distanceBetweenJointsIndex >= hand.distanceForJointsApart &&
                distanceBetweenJointsMiddle >= hand.distanceForJointsApart &&
                distanceBetweenJointsLittle <= hand.distanceForJointsApart &&
                distanceBetweenJointsRing <= hand.distanceForJointsApart) {
                    hand.handPose = .peaceSign
                    return true
            }
        }
        
        return false
    }
    
    func checkPose_OpenPalm(hand: Hand) -> Bool {
        if let wristJoint = hand.joints.filter({ $0.handPart == .wrist}).first,
           let littleFingerTip = hand.joints.filter({ $0.handPart == .littleFingerTip}).first,
           let ringFingerTip = hand.joints.filter({ $0.handPart == .ringFingerTip}).first,
           let indexFingerTip = hand.joints.filter({ $0.handPart == .indexFingerTip}).first,
           let middleFingerTip = hand.joints.filter({ $0.handPart == .middleFingerTip}).first {
            
            let distanceBetweenJointsLittle = distance(wristJoint.position, littleFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsRing = distance(wristJoint.position, ringFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsIndex = distance(wristJoint.position, indexFingerTip.position) * hand.normaliseDistance
            let distanceBetweenJointsMiddle = distance(wristJoint.position, middleFingerTip.position) * hand.normaliseDistance
                        
            if (distanceBetweenJointsIndex >= hand.distanceForJointsApart &&
                distanceBetweenJointsMiddle >= hand.distanceForJointsApart &&
                distanceBetweenJointsLittle >= hand.distanceForJointsApart &&
                distanceBetweenJointsRing >= hand.distanceForJointsApart) {
                    hand.handPose = .openPalm
                    return true
            }
        }
        
        return false
    }
}
