//
//  GameScene.swift
//  Commotion
//
//  Code adapted from Eric Larson's Sprite Game on 9/6/16.
//  Copyright © 2016 Eric Larson. All rights reserved.
// Adapted by Eric Miao, Joshua Sylvester, Canon Ellis on 10/15/21.

import UIKit
import SpriteKit
import CoreMotion

protocol GameViewControllerDelegate: class {
    func gameOver()
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    weak var gameViewControllerDelegate:GameViewControllerDelegate?

    // MARK: Raw Motion Functions
    let motion = CMMotionManager()
    func startMotionUpdates(){
        // if motion is available, start updating the device motion
        if self.motion.isDeviceMotionAvailable{
            self.motion.deviceMotionUpdateInterval = 0.2
            self.motion.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: self.handleMotion )
        }
    }
    
    func handleMotion(_ motionData:CMDeviceMotion?, error:Error?){
        // make gravity in the game als the simulator gravity
        if let gravity = motionData?.gravity {
            self.physicsWorld.gravity = CGVector(dx: CGFloat(9.8*gravity.x), dy: CGFloat(9.8*gravity.y))
        }
    }
    
    // MARK: View Hierarchy Functions
    // this is like out "View Did Load" function
    override func didMove(to view: SKView) {

        physicsWorld.contactDelegate = self
        backgroundColor = SKColor.white
        
        // start motion for gravity
        self.startMotionUpdates()
        
        // make the maze
        self.addSides()
        self.addMaze()
        self.setupBlackHoles()
        self.addGoalBlock()
        self.playGame()
    }
    
    // MARK: Create Sprites
    let movingBlock = SKSpriteNode()
    let goalBlock = SKSpriteNode(imageNamed: "finish")
    let marble = SKSpriteNode(imageNamed: "Marble")
    let livesLabel = SKLabelNode(fontNamed: "Chalkduster")
    var blackHoles: [SKSpriteNode] = [SKSpriteNode]()
    var yesterdaysSteps: Float = 0
    var lives:Int = 0{
        willSet(newValue){
            DispatchQueue.main.async{
                self.livesLabel.text = "Lives: \(newValue)"
            }
        }
    }
    
    // MARK: Game Setup Functions
    func setYesterdaysSteps(ySteps: Float){
        self.yesterdaysSteps = ySteps
    }
    
    // The game's init function which adds the pertitent elements to the maze and sets the lives
    func playGame(){
        self.addMovingBlock() // add a block which the user has to avoid to win the game
        self.addMarble() // add the marble the user will navigate through the maze
        self.addLivesLabel() // add the lives label
    }
    
    // Sets up the number of lives to be contingent on yesterday's step count
    func addLivesLabel(){
        lives = Int(yesterdaysSteps/100)
        livesLabel.text = "Lives: " + String(lives)
        livesLabel.fontSize = 20
        livesLabel.fontColor = SKColor.blue
        livesLabel.position = CGPoint(x: frame.midX, y: size.height - 115)
        
        self.addChild(livesLabel)
    }
    
    
    // Adds the marble into the maze
    func addMarble(){
        marble.size = CGSize(width:22,height:22)
        
        let randNumber = random(min: CGFloat(0.1), max: CGFloat(0.9))
        marble.position = CGPoint(x: size.width * randNumber, y: size.height * 0.75)
        
        marble.physicsBody = SKPhysicsBody(rectangleOf:marble.size)
        marble.physicsBody?.restitution = random(min: CGFloat(0.2), max: CGFloat(0.2))
        marble.physicsBody?.isDynamic = true
        // for collision detection we need to setup these masks
        marble.physicsBody?.contactTestBitMask = 0x00000001
        marble.physicsBody?.collisionBitMask = 0x00000001
        marble.physicsBody?.categoryBitMask = 0x00000001
        
        self.addChild(marble)
    }
    
    // Adds a moving block in the game which can impede the marble in getting to the goal
    func addMovingBlock() {
        movingBlock.color = UIColor.red
        movingBlock.size = CGSize(width:30,height:30)
        movingBlock.position = CGPoint(x: size.width * 0.7, y: size.height * 0.35)

        movingBlock.physicsBody = SKPhysicsBody(rectangleOf:movingBlock.size)
        movingBlock.physicsBody?.contactTestBitMask = 0x00000001
        movingBlock.physicsBody?.collisionBitMask = 0x00000001
        movingBlock.physicsBody?.categoryBitMask = 0x00000001
        movingBlock.physicsBody?.isDynamic = true
    
        self.addChild(movingBlock)
    }
    
    // Put three black holes into the maze that can kill the marble
    func setupBlackHoles(){
        let blackHole1 = SKSpriteNode(imageNamed: "blackHole")
        blackHole1.name = "blackHole1"
        blackHole1.position = CGPoint(x: size.width * 0.25, y: size.height * 0.05)
        blackHoles.append(blackHole1)
        
        let blackHole2 = SKSpriteNode(imageNamed: "blackHole")
        blackHole2.name = "blackHole2"
        blackHole2.position = CGPoint(x: size.width * 0.9, y: size.height * 0.05)
        blackHoles.append(blackHole2)
        
        let blackHole3 = SKSpriteNode(imageNamed: "blackHole")
        blackHole3.name = "blackHole3"
        blackHole3.position = CGPoint(x: size.width * 0.3, y: size.height * 0.8)
        blackHoles.append(blackHole3)

        
        for blackHole in blackHoles {
            blackHole.color = UIColor.black
            blackHole.size = CGSize(width:size.width*0.1,height:size.height * 0.05)

            blackHole.physicsBody = SKPhysicsBody(rectangleOf: blackHole.size)
            blackHole.physicsBody?.isDynamic = false
            
            self.addChild(blackHole)
        }
    }
    
    // Add the finishing block
    func addGoalBlock() {
        goalBlock.color = UIColor.green
        goalBlock.size = CGSize(width:size.width*0.12,height:size.height * 0.05)
        goalBlock.position = CGPoint(x: size.width * 0.31, y: size.height * 0.5)

        goalBlock.physicsBody = SKPhysicsBody(rectangleOf:goalBlock.size)
        goalBlock.physicsBody?.isDynamic = true
        goalBlock.physicsBody?.pinned = true
    
        self.addChild(goalBlock)
    }
    
    // Function used for adding walls to the maze
    func addStaticBlockAtPoint(_ point:CGPoint){
        let mazeWall = SKSpriteNode()

        mazeWall.color = UIColor.blue
        mazeWall.size = CGSize(width:size.width*0.1,height:size.height * 0.05)
        mazeWall.position = point

        mazeWall.physicsBody = SKPhysicsBody(rectangleOf:mazeWall.size)
        mazeWall.physicsBody?.isDynamic = true
        mazeWall.physicsBody?.pinned = true
        mazeWall.physicsBody?.allowsRotation = false

        self.addChild(mazeWall)
    }

    // Add the maze's outermost borders
    func addSides(){
        let left = SKSpriteNode()
        let right = SKSpriteNode()
        let top = SKSpriteNode()
        let bottom = SKSpriteNode()
        
        left.size = CGSize(width:size.width*0.1,height:size.height)
        left.position = CGPoint(x:0, y:size.height*0.5)
        
        right.size = CGSize(width:size.width*0.1,height:size.height)
        right.position = CGPoint(x:size.width, y:size.height*0.5)
        
        top.size = CGSize(width:size.width,height:size.height*0.05)
        top.position = CGPoint(x:size.width*0.5, y:size.height - 70)
        
        bottom.size = CGSize(width:size.width,height:size.height*0.05)
        bottom.position = CGPoint(x:size.width*0.5, y:0)
        
        for obj in [left,right,top, bottom]{
            obj.color = UIColor.red
            obj.physicsBody = SKPhysicsBody(rectangleOf:obj.size)
            obj.physicsBody?.isDynamic = true
            obj.physicsBody?.pinned = true
            obj.physicsBody?.allowsRotation = false
            self.addChild(obj)
        }
    }
    
    // Actually create the inner-walls of the maze
    func addMaze(){
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.35, y: size.height * 0.05))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.10))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.25, y: size.height * 0.10))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.30, y: size.height * 0.10))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.35, y: size.height * 0.10))
        
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.15))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.40, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.45, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.55, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.25))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.40, y: size.height * 0.25))
        
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.30))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.35))
    
        
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.25, y: size.height * 0.35))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.30, y: size.height * 0.35))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.35, y: size.height * 0.35))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.40, y: size.height * 0.35))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.45, y: size.height * 0.35))
        
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.25, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.30, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.35, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.40, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.45, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.55, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.60, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.65, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.65, y: size.height * 0.40))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.65, y: size.height * 0.35))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.85, y: size.height * 0.35))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.90, y: size.height * 0.35))


        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.65, y: size.height * 0.30))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.65, y: size.height * 0.25))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.65, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.75, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.80, y: size.height * 0.20))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.65, y: size.height * 0.10))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.65, y: size.height * 0.05))


        
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.45))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.50))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.55))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.60))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.65))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.80, y: size.height * 0.65))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.70))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.75))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.70, y: size.height * 0.80))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.75, y: size.height * 0.80))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.80, y: size.height * 0.80))


        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.50))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.55))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.60))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.65))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.70))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.75))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.80))
        
        
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.50))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.55))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.60))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.65))

        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.25, y: size.height * 0.65))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.30, y: size.height * 0.65))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.30, y: size.height * 0.70))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.30, y: size.height * 0.70))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.75))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.30, y: size.height * 0.75))

        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.80))
        self.addStaticBlockAtPoint(CGPoint(x: size.width * 0.20, y: size.height * 0.84))
    }
    
    
    // MARK: Collision and Game Mechanic Functions
    
    // didBegin handles the black hole contacts which destroy balls or the contact with the goal block which wins the game
    // The destroy blocks were made while referencing this tutorial:
    // https://www.hackingwithswift.com/read/11/5/collision-detection-skphysicscontactdelegate
    func didBegin(_ contact: SKPhysicsContact) {
        if ( blackHoles.contains(contact.bodyA.node as! SKSpriteNode) || blackHoles.contains(contact.bodyB.node as! SKSpriteNode) ) && (contact.bodyA.node == marble || contact.bodyB.node == marble) {
            handleLostMarble()
        }
        
        if (contact.bodyA.node == goalBlock || contact.bodyB.node == goalBlock) && (contact.bodyA.node == marble || contact.bodyB.node == marble) {
            displayGameWon()
        }
    }
    
    // Handles a lost marble and either ends the game or respawns depending on life count
    func handleLostMarble(){
        lives -= 1
        
        marble.removeFromParent()
        
        if lives <= 0 { // game over
            displayGameLost()
        } else { // use another life
            addMarble()
        }
    }
    
    // MARK: Game Ending Functions
    // function for when user loses the game
    func displayGameLost(){
        marble.removeFromParent()
        movingBlock.removeFromParent()
        
        let alert = UIAlertController(title: "You Lost", message: "You ran out of lives, try to take more steps so that you have more lives to use in a game.", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Leave Game", style: .default, handler: {
            (UIAlertAction) in
            self.localGameOver()
        }))
        alert.addAction(UIAlertAction(title: "Play Again", style: .cancel, handler: {
            (UIAlertAction) in
            self.livesLabel.removeFromParent()
            self.playGame()
        }))

        view?.window?.rootViewController?.present(alert, animated: true)
    }
    
    // Uses delegate to transition the user back to the root view controller
    func localGameOver(){
        gameViewControllerDelegate?.gameOver() // https://riptutorial.com/sprite-kit/example/27792/protocol-delegate-to-call-a-game-viewcontroller-method-from-the-game-scene
    }
    
    // For when the user wins
    func displayGameWon(){
        marble.removeFromParent()
        movingBlock.removeFromParent()
        
        // Referenced this tutorial for setting up the alert: https://stackoverflow.com/questions/39557344/swift-spritekit-how-to-present-alert-view-in-gamescene
        let alert = UIAlertController(title: "You Won!! 🎉", message: "Congrats you solved the mazed!", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Leave Game", style: .default, handler: {
            (UIAlertAction) in
            self.localGameOver()
        }))
        alert.addAction(UIAlertAction(title: "Play Again", style: .cancel, handler: {
            (UIAlertAction) in
            self.livesLabel.removeFromParent()
            self.playGame()
        }))


        view?.window?.rootViewController?.present(alert, animated: true)
    }
    
    // MARK: Utility Functions (thanks ray wenderlich!)
    // generate some random numbers for cor graphics floats
    func random() -> CGFloat {
        return CGFloat(Float(arc4random()) / Float(Int.max))
    }
    
    func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return random() * (max - min) + min
    }
}
