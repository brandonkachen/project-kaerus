/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit
import Firebase
import FBSDKCoreKit
import FBSDKLoginKit

class LoginViewController: UIViewController {

	// MARK: Constants
	let LoggedIn = "LoggedIn"

	// MARK: Outlets
//	@IBOutlet weak var textFieldLoginEmail: UITextField!
//	@IBOutlet weak var textFieldLoginPassword: UITextField!
	@IBOutlet weak var titleLabel: UILabel!

	@IBOutlet weak var splashScreen: UIView!
	@IBOutlet weak var logo: UILabel!
	
	// MARK: Properties
	
	// MARK: UIViewController Lifecycle
	@IBAction func facebookLogin (sender: AnyObject){
		let facebookLogin = FBSDKLoginManager()
		facebookLogin.logOut()
		
		facebookLogin.logInWithReadPermissions(["email", "user_friends"], fromViewController: self, handler:{(facebookResult, facebookError) -> Void in
			if facebookError != nil { print("Facebook login failed. Error \(facebookError)")
			} else if facebookResult.isCancelled { print("Facebook login was cancelled.")
			} else {
				// show splash screen after user successfully logs in
				self.splashScreen.hidden = false
				self.splashScreen.alpha = 1
				self.logo.alpha = 1
				
				let credential = FIRFacebookAuthProvider.credentialWithAccessToken(FBSDKAccessToken.currentAccessToken().tokenString)
				FIRAuth.auth()?.signInWithCredential(credential) { (user, error) in
					if let error = error {
						print(error.localizedDescription)
						return
					}
					self.signedIn(user!)
				}
			}
		});
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// show splash screen
		splashScreen.alpha = 1
		logo.alpha = 1

		FIRAuth.auth()?.addAuthStateDidChangeListener { auth, user in
			if user != nil && FBSDKAccessToken.currentAccessToken() != nil {
				// user is logged in: load their info, then go to Goals screen
				self.signedIn(user)
			}
			else {
				self.splashScreen.hidden = true
				self.splashScreen.alpha = 0
				self.logo.alpha = 0
			}
		}
	}

	// MARK: Actions
//	@IBAction func loginDidTouch(sender: AnyObject) {
//		// Sign In with credentials.
//		let email = textFieldLoginEmail.text
//		let password = textFieldLoginPassword.text
//		FIRAuth.auth()?.signInWithEmail(email!, password: password!) { (user, error) in
//			if let error = error {
//				print(error.localizedDescription)
//				return
//			}
//			self.signedIn(user!)
//		}
//	}
//
//	@IBAction func signUpDidTouch(sender: AnyObject) {
//		let email = textFieldLoginEmail.text
//		let password = textFieldLoginPassword.text
//		FIRAuth.auth()?.createUserWithEmail(email!, password: password!) { (user, error) in
//			if let error = error {
//				print(error.localizedDescription)
//				return
//			}
//			self.setDisplayName(user!)
//		}
//	}
	
	func setDisplayName(user: FIRUser) {
		let changeRequest = user.profileChangeRequest()
		changeRequest.displayName = user.email!.componentsSeparatedByString("@")[0]
		changeRequest.commitChangesWithCompletion(){ (error) in
			if let error = error {
				print(error.localizedDescription)
				return
			}
			self.signedIn(FIRAuth.auth()?.currentUser)
		}
	}
	
	func signedIn(user: FIRUser?) {
		MeasurementHelper.sendLoginEvent()
		AppState.sharedInstance.setState(user)
		NSNotificationCenter.defaultCenter().postNotificationName(Constants.NotificationKeys.SignedIn, object: nil, userInfo: nil)
		
		// Add user to firebase database, if not already in there
		let graphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields" : "id, first_name"])
		graphRequest.startWithCompletionHandler({ (connection, result, error) -> Void in
			if ((error) != nil) {
				print("Error: \(error)")
			} else {
				let fbID = result.valueForKey("id") as! String
				AppState.sharedInstance.firstName = result.valueForKey("first_name") as! String
				let idRef = FIRDatabase.database().reference().child("FB-to-FIR/\(fbID)") // fbID is unique. get this so others can find user by their fb id
				let partnerStatusRef = FIRDatabase.database().reference().child("Has-Partner/\(user!.uid)")

				// get partner status
				partnerStatusRef.observeEventType(.Value, withBlock: { snapshot in
					let partnerStatus = snapshot.value as! Bool
					// get user's id
					idRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
						if snapshot.value as? String != nil {
							AppState.sharedInstance.partnerStatus = partnerStatus
						} else { // first time logging in
							idRef.setValue(user?.uid)
							partnerStatusRef.setValue(false)
						}
						self.performSegueWithIdentifier(self.LoggedIn, sender: nil)
					})
				})
			}
		})
	}
}

