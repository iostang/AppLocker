//
//  AppALConstants.swift
//  AppLocker
//
//  Created by Oleg Ryasnoy on 07.07.17.
//  Copyright © 2017 Oleg Ryasnoy. All rights reserved.
//

import UIKit
import AudioToolbox
import LocalAuthentication
import Valet

public enum ALConstants {
  static let nibName = "AppLocker"
  static let kPincode = "pincode" // Key for saving pincode to keychain
  static let kLocalizedReason = "Unlock with sensor" // Your message when sensors must be shown
  static let duration = 0.3 // Duration of indicator filling
  static let maxPinLength = 4
  
  enum button: Int {
    case delete = 1000
    case cancel = 1001
  }
}

public struct ALAppearance { // The structure used to display the controller
  public var title: String?
  public var subtitle: String?
  public var image: UIImage?
  public var color: UIColor?
  public var isSensorsEnabled: Bool?
    
  public var createTitle: String?
  public var confirmPwTitle: String?
  public var confirmPcTitle: String?
    
  public init() {}
}

public enum ALMode { // Modes for AppLocker
  case validate
  case change
  case deactive
  case create
}

public class AppLocker: UIViewController {
  
  // MARK: - Top view
  @IBOutlet weak var messageLabel: UILabel!
  @IBOutlet weak var submessageLabel: UILabel!
  @IBOutlet var pinIndicators: [Indicator]!
    
  @IBOutlet public weak var cancelButton: UIButton!
  @IBOutlet public weak var photoImageView: UIImageView!
  @IBOutlet public weak var deleteButton: UIButton!
    
  public var appearance: ALAppearance?
    
  public static let valet = Valet.valet(with: Identifier(nonEmpty: "Druidia")!, accessibility: .whenUnlockedThisDeviceOnly)  
  // MARK: - Pincode
  private let context = LAContext()
  private var pin = "" // Entered pincode
  private var reservedPin = "" // Reserve pincode for confirm
  private var isFirstCreationStep = true
  private var savedPin: String? {
    get {
        do {
            return try AppLocker.valet.string(forKey: ALConstants.kPincode)
        } catch {
            return nil
        }
    }
    set {
      guard let newValue = newValue else { return }
        do {
            try AppLocker.valet.setString(newValue, forKey: ALConstants.kPincode)
        } catch {
            
        }
    }
  }
  
  fileprivate var mode: ALMode? {
    didSet {
      let mode = self.mode ?? .validate
      switch mode {
      case .create:
        submessageLabel.text = appearance?.createTitle
      //"Create your passcode" // Your submessage for create mode
      case .change:
        submessageLabel.text = appearance?.confirmPwTitle
      //"Enter your passcode" // Your submessage for change mode
      case .deactive:
        submessageLabel.text = appearance?.confirmPwTitle
      //"Enter your passcode" // Your submessage for deactive mode
      case .validate:
        submessageLabel.text = appearance?.confirmPwTitle
        //"Enter your passcode" // Your submessage for validate mode
        cancelButton.isHidden = true
        isFirstCreationStep = false
      }
    }
  }
  
  private func precreateSettings () { // Precreate settings for change mode
    mode = .create
    clearView()
  }
  
  private func drawing(isNeedClear: Bool, tag: Int? = nil) { // Fill or cancel fill for indicators
    let results = pinIndicators.filter { $0.isNeedClear == isNeedClear }
    let pinView = isNeedClear ? results.last : results.first
    pinView?.isNeedClear = !isNeedClear
    
    UIView.animate(withDuration: ALConstants.duration, animations: {
      pinView?.backgroundColor = isNeedClear ? .clear : .white
    }) { _ in
      isNeedClear ? self.pin = String(self.pin.dropLast()) : self.pincodeChecker(tag ?? 0)
    }
  }
  
  private func pincodeChecker(_ pinNumber: Int) {
    if pin.count < ALConstants.maxPinLength {
      pin.append("\(pinNumber)")
      if pin.count == ALConstants.maxPinLength {
        switch mode ?? .validate {
        case .create:
          createModeAction()
        case .change:
          changeModeAction()
        case .deactive:
          deactiveModeAction()
        case .validate:
          validateModeAction()
        }
      }
    }
  }
  
  // MARK: - Modes
  private func createModeAction() {
    if isFirstCreationStep {
      isFirstCreationStep = false
      reservedPin = pin
      clearView()
      submessageLabel.text = appearance?.confirmPcTitle
        //"Confirm your pincode"
    } else {
      confirmPin()
    }
  }
  
  private func changeModeAction() {
    pin == savedPin ? precreateSettings() : incorrectPinAnimation()
  }
  
  private func deactiveModeAction() {
    pin == savedPin ? removePin() : incorrectPinAnimation()
  }
  
  private func validateModeAction() {
    pin == savedPin ? dismiss(animated: true, completion: nil) : incorrectPinAnimation()
  }
  
  private func removePin() {
    do {
        try AppLocker.valet.removeObject(forKey: ALConstants.kPincode)
    } catch {
        
    }
    dismiss(animated: true, completion: nil)
  }
  
  private func confirmPin() {
    if pin == reservedPin {
      savedPin = pin
      dismiss(animated: true, completion: nil)
    } else {
      incorrectPinAnimation()
    }
  }
  
  private func incorrectPinAnimation() {
    pinIndicators.forEach { view in
      view.shake(delegate: self)
      view.backgroundColor = .clear
    }
    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
  }
  
  fileprivate func clearView() {
    pin = ""
    pinIndicators.forEach { view in
      view.isNeedClear = false
      UIView.animate(withDuration: ALConstants.duration, animations: {
        view.backgroundColor = .clear
      })
    }
  }
  
  // MARK: - Touch ID / Face ID
  fileprivate func checkSensors() {
    guard mode == .validate else {return}
    
    var policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics // iOS 8+ users with Biometric and Custom (Fallback button) verification
    
    // Depending the iOS version we'll need to choose the policy we are able to use
    if #available(iOS 9.0, *) {
      // iOS 9+ users with Biometric and Passcode verification
      policy = .deviceOwnerAuthentication
    }
    
    var err: NSError?
    // Check if the user is able to use the policy we've selected previously
    guard context.canEvaluatePolicy(policy, error: &err) else {return}
    
    // The user is able to use his/her Touch ID / Face ID 👍
    context.evaluatePolicy(policy, localizedReason: ALConstants.kLocalizedReason, reply: {  success, error in
      if success {
        if (Thread.isMainThread) {
            self.dismiss(animated: true, completion: nil)
        } else {
            DispatchQueue.main.sync {
                self.dismiss(animated: true, completion: nil)
            }
        }
      }
    })
  }
  
  // MARK: - Keyboard
  @IBAction func keyboardPressed(_ sender: UIButton) {
    switch sender.tag {
    case ALConstants.button.delete.rawValue:
      drawing(isNeedClear: true)
    case ALConstants.button.cancel.rawValue:
      clearView()
      dismiss(animated: true, completion: nil)
    default:
      drawing(isNeedClear: false, tag: sender.tag)
    }
  }
  
}

// MARK: - CAAnimationDelegate
extension AppLocker: CAAnimationDelegate {
  public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
    clearView()
  }
}

// MARK: - Present
public extension AppLocker {
  // Present AppLocker
    class func present(with mode: ALMode, and config: ALAppearance? = nil, controller: UIViewController? = nil) {
    guard let root = controller ?? UIApplication.shared.keyWindow?.rootViewController,

      let locker = Bundle(for: self.classForCoder()).loadNibNamed(ALConstants.nibName, owner: self, options: nil)?.first as? AppLocker else {
        return
    }
    locker.appearance = config
    locker.messageLabel.text = config?.title ?? ""
    locker.submessageLabel.text = config?.subtitle ?? ""
    locker.view.backgroundColor = config?.color ?? .black
    locker.mode = mode
    
    if config?.isSensorsEnabled ?? false {
      locker.checkSensors()
    }
    
    if let image = config?.image {
      locker.photoImageView.image = image
    } else {
      locker.photoImageView.isHidden = true
    }
    locker.modalPresentationStyle = root.modalPresentationStyle
    root.present(locker, animated: true, completion: nil)
  }
}
