//
//  GameViewController.swift
//  Commotion
//
//  Code adapted from Eric Larson's Sprite Game on 9/6/16.
//  Copyright © 2016 Eric Larson. All rights reserved.
//  Adapted by Eric Miao, Joshua Sylvester, Canon Ellis on 10/15/21.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController, GameViewControllerDelegate {
    var yesterdaySteps: Float = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //setup game scene
        let scene = GameScene(size: view.bounds.size)
        scene.gameViewControllerDelegate = self
        scene.setYesterdaysSteps(ySteps: yesterdaySteps)
        let skView = view as! SKView // the view in storyboard must be an SKView
        skView.showsFPS = true // show some debugging of the FPS
        skView.showsNodeCount = true // show how many active objects are in the scene
        skView.ignoresSiblingOrder = true // don't track who entered scene first
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }

    // don't show the time and status bar at the top
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // Delegate function for the gamescene to make use of when user needs to return to the rootviewcontroller
    func gameOver() {
        self.navigationController?.popViewController(animated: true)
    }
}
