//
//  ImmersiveView.swift
//  HandsTest
//
//  Created by Ben Harraway on 15/12/2023.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    
    let simulatorHandTrackingProvider = SimulatorHandTrackingProvider()
    
    let bonjour = BonjourSession(configuration: .default)

    let anchorHead = AnchorEntity(.head)
    
    var body: some View {
        RealityView { content in
            
            anchorHead.anchoring.trackingMode = .continuous
            content.add(anchorHead)

            simulatorHandTrackingProvider.start()
            simulatorHandTrackingProvider.addHands(content, anchorHead)
            
            addTestBall(content: content)
        }
    }
    
    
    func addTestBall(content: RealityViewContent) {
        let xx = -0.2 + (Float(arc4random_uniform(40))/100.0)
        let radius:Float = 0.03 + (Float(arc4random_uniform(7))/100.0)
        let randomColor = [UIColor.magenta, UIColor.purple, UIColor.red, UIColor.yellow, UIColor.black, UIColor.cyan].randomElement()
        
        let testBall = ModelEntity(mesh: .generateSphere(radius: radius))
            testBall.model?.materials = [SimpleMaterial(color: randomColor!, isMetallic: false)]
        testBall.position = SIMD3<Float>(x: xx, y: 0.8, z: -0.6)
        
        let spherePhysics = PhysicsBodyComponent(
                                massProperties: .default,
                                material: .generate(friction: 0.5, restitution: 0.1),
                                mode: .dynamic)
                            
        testBall.components.set(spherePhysics)
  
        let collisionShape = ShapeResource.generateSphere(radius: radius)
        let collisionComp = CollisionComponent(shapes: [collisionShape])
        testBall.components.set(collisionComp)
        
        testBall.setParent(anchorHead)
        
        DispatchQueue.main.asyncAfter(deadline: .now()+5.0, execute: {
            testBall.removeFromParent()
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
            addTestBall(content: content)
        })
    }    
}

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
