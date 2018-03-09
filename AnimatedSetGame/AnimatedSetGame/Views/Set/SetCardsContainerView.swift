//
//  CardContainerView.swift
//  GraphicalSetGamee
//
//  Created by Tiago Maia Lopes on 09/02/18.
//  Copyright © 2018 Tiago Maia Lopes. All rights reserved.
//

import UIKit

/// The view responsible for holding and displaying a grid of cardButtons.
@IBDesignable
class SetCardsContainerView: CardsContainerView, UIDynamicAnimatorDelegate {
  
  // MARK: Properties
  
  /// The translated deck frame used by the dealing animation.
  /// - Note: This frame is the origin and size for all added buttons.
  ///         When the deal animation takes place, all cards will fly from
  ///         this frame to each destination.
  var deckFrame: CGRect!
  
  /// The translated matched deck frame used by the removal animation.
  /// - Note: When the removal animation takes place, all cards will fly from
  ///         their current position to this frame.
  var matchedDeckFrame: CGRect!
  
  /// The animator object responsible for each button's animations.
  lazy private var animator = UIDynamicAnimator(referenceView: self)
  
  /// Tells if the dealing animation is running.
  /// If it's running, we shouldn't overlap the current dealing one.
  /// Only one deal animation must be performed at a time.
  private(set) var isPerformingDealAnimation = false
  
  /// The number of buttons to be displayed on a storyboard file with this view in it.
  @IBInspectable private var numberOfButtonsForDisplay: Int = 0
  
  // MARK: Initializer
  
  override func awakeFromNib() {
    animator.delegate = self
  }
  
  // MARK: View life cycle
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    // Only updates the buttons frames if the centered rect has changed,
    // This will occur when orientation changes.
    // This check will prevent frame changes while
    // the animator is doing it's job.
    if grid.frame != gridRect {
      updateViewsFrames()
    }
  }
  
  /// Draws the card buttons for storyboard display.
  /// - Note: The button's properties are randomly generated.
  override func prepareForInterfaceBuilder() {
    super.prepareForInterfaceBuilder()
    
    if numberOfButtonsForDisplay > 0 {
      addCardButtons(byAmount: numberOfButtonsForDisplay)
      
      respositionViews()
      
      for button: SetCardButton in buttons as! [SetCardButton] {
        button.alpha = 1
        button.isFaceUp = true
        
        button.symbolShape = SetCardButton.CardSymbolShape.randomized()
        button.color = SetCardButton.CardColor.randomized()
        button.symbolShading = SetCardButton.CardSymbolShading.randomized()
        button.numberOfSymbols = 4.arc4random
        
        if (button.numberOfSymbols == 0 || button.numberOfSymbols > 3) {
          button.numberOfSymbols = 1
        }
        
        button.setNeedsDisplay()
      }
    }
  }
  
  // MARK: Imperatives
  
  /// Adds new buttons to the UI.
  /// - Parameter byAmount: The number of buttons to be added.
  /// - Parameter animated: Bool indicating if the addition should be animated.
  func addCardButtons(byAmount numberOfButtons: Int = 3, animated: Bool = false) {
    guard isPerformingDealAnimation == false else { return }
    
    let cardButtons = (0..<numberOfButtons).map { _ in SetCardButton() }
    
    for button in cardButtons {
      // Each button is hidden and face down by default.
      button.alpha = 0
      button.isFaceUp = false
      
      addSubview(button)
      buttons.append(button)
    }
    
    grid.cellCount += cardButtons.count
    grid.frame = gridRect
    
    if animated {
      animateCardButtonsDeal()
    }
  }
  
  /// Animates all empty cards to their original position.
  ///
  /// - Note: The animation is performed by taking a copy of
  ///         each hidden button and animating them from the deck
  ///         to their current position.
  func animateCardButtonsDeal() {
    // The animation is only performed if a previous one isn't happening.
    // If two animations run at the same time, the frame is changed and the
    // animator doesn't handle this well.
    guard isPerformingDealAnimation == false else { return }
    
    // The animation is only applied to the hidden cards.
    guard buttons.filter({ $0.alpha == 0 }).count > 0 else { return }
    
    // The animation now has taken place.
    isPerformingDealAnimation = true
    
    updateViewsFrames(withAnimation: true) {
      var dealAnimationDelay = 0.0
      
      for (i, button) in self.buttons.enumerated() {
        // The deal animation is applied only to the hidden buttons.
        if button.alpha != 0 { continue }
        
        guard let currentFrame = self.grid[i] else { continue }
        
        button.isFaceUp = false
        
        // Change the position and size to match the provided deck's frame.
        button.frame = self.deckFrame
        self.bringSubview(toFront: button)
        
        // The card will appear on top of the deck.
        button.alpha = 1
        
        let snapBehavior = UISnapBehavior(item: button,
                                          snapTo: currentFrame.center)
        snapBehavior.damping = 0.8
        
        Timer.scheduledTimer(withTimeInterval: dealAnimationDelay, repeats: false) { _ in
          // Apply the snap behavior.
          self.animator.addBehavior(snapBehavior)
          
          // Animates the button's size.
          UIViewPropertyAnimator.runningPropertyAnimator(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseIn,
            animations: {
              button.bounds.size = currentFrame.size
            }
          )
          
          // Flips the card.
          Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
            button.flipCard(animated: true)
          }
        }
        
        dealAnimationDelay += 0.2
      }
    }
  }
  
  /// Animates the passed buttons out of the table and on
  /// to the pile of matched cards.
  ///
  /// - Note: The animation takes place in three steps:
  ///         * A scale transformation is applied
  ///         * The buttons are concentrated in the center of this view
  ///         * The cards are flipped
  ///         * The cards are put in the matched pile
  override func animateCardsOut(_ buttons: [CardButton]) {
    guard matchedDeckFrame != nil else { return }
    guard let buttons = buttons as? [SetCardButton] else { return }
    
    var buttonsCopies = [SetCardButton]()
    
    for button in buttons {
      // Creates the button copy used to be animated.
      let buttonCopy = button.copy(with: nil) as! SetCardButton
      buttonsCopies.append(buttonCopy)
      addSubview(buttonCopy)
      
      // Hides the original button.
      button.alpha = 0
    }
    
    // Starts animating by scaling each button.
    UIViewPropertyAnimator.runningPropertyAnimator(
      withDuration: 0.1,
      delay: 0,
      options: .curveEaseIn,
      animations: {

        buttonsCopies.forEach {
          $0.bounds.size = CGSize(
            width: $0.frame.size.width * 1.1,
            height: $0.frame.size.height * 1.1
          )
        }
        
    }, completion: { position in
      
      // Animates each card to the center of the container view.
      UIViewPropertyAnimator.runningPropertyAnimator(
        withDuration: 0.2,
        delay: 0,
        options: .curveEaseIn,
        animations: {
          
          buttonsCopies.forEach { $0.center = self.center }
          
      }, completion: { position in
        // Flips each card down
        buttonsCopies.forEach { $0.flipCard() }
        
        // Animates each card to the matched deck.

        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
          buttonsCopies.forEach { button in
            let snapOutBehavior = UISnapBehavior(item: button, snapTo: self.matchedDeckFrame.center)
            snapOutBehavior.damping = 0.8
            self.animator.addBehavior(snapOutBehavior)
            
            UIViewPropertyAnimator.runningPropertyAnimator(
              withDuration: 0.2,
              delay: 0,
              options: .curveEaseIn,
              animations: {
                button.bounds.size = self.matchedDeckFrame.size
              }
            )
          }
        }
        
        UIViewPropertyAnimator.runningPropertyAnimator(
          withDuration: 0.2,
          delay: 1,
          options: .curveEaseInOut,
          animations: {
            buttonsCopies.forEach { $0.alpha = 0 }
        }) { _ in
          buttonsCopies.forEach {
            $0.removeFromSuperview()
          }
          
          // Calls the delegate, if set.
          if let delegate = self.delegate {
            delegate.cardsRemovalDidFinish()
          }
        }

      })
    })
  }
  
  // MARK: UIDynamicAnimator Delegate methods
  
  func dynamicAnimatorDidPause(_ animator: UIDynamicAnimator) {
    animator.removeAllBehaviors()
    isPerformingDealAnimation = false
  }
  
}

