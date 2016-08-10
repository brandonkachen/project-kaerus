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
	let group = dispatch_group_create()

	// MARK: Outlets
//	@IBOutlet weak var textFieldLoginEmail: UITextField!
//	@IBOutlet weak var textFieldLoginPassword: UITextField!
	@IBOutlet weak var titleLabel: UILabel!

	@IBOutlet weak var splashScreen: UIView!
	
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
		let user = FIRAuth.auth()?.currentUser
		
		if user != nil && FBSDKAccessToken.currentAccessToken() != nil {
			// user is logged in: load their info, then go to Goals screen
			self.signedIn(user)
		} else {
			self.splashScreen.hidden = true
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

		dispatch_group_enter(group)
		// Add user to firebase database, if not already in there
		let graphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields" : "id, first_name, picture.width(200).height(200)"])
		graphRequest.startWithCompletionHandler(){ (connection, result, error) -> Void in
			if ((error) != nil) {
				print("Error: \(error)")
			} else {
				// fbID needed for FB-to-FIR conversion
				let fbID = result.valueForKey("id") as! String
				
				// firstName not included in FIRUser object
				AppState.sharedInstance.firstName = result.valueForKey("first_name") as! String
				
				// default picture is too low quality
				let picName = result.valueForKey("picture")?.objectForKey("data")?.objectForKey("url") as! String
				AppState.sharedInstance.photoUrl = NSURL(string: picName)!
				AppState.sharedInstance.photo = UIImage(data: NSData(contentsOfURL: AppState.sharedInstance.photoUrl)!)!.circle
				
				// fbID is unique. get this so others can find user by their fb id (when user is looking for a partner)
				let fbToFirRef = FIRDatabase.database().reference().child("FB-to-FIR/\(fbID)")
				fbToFirRef.setValue(user?.uid)
				
				/* if firebase counts modifying a value to the same value as using bandwidth, use this
				firstTimeLoginRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
					if snapshot.value as? String == nil{
						firstTimeLoginRef.setValue(user?.uid)
					}
				})*/
			}
			dispatch_group_leave(self.group)
		}

		partnerSetup()
		oneSignalIdSetup()
		startDateSetup()
		
		dispatch_group_notify(group, dispatch_get_main_queue()) {
			self.performSegueWithIdentifier(self.LoggedIn, sender: nil)
		}
	}
	
	// get partner status
	func partnerSetup() {
		dispatch_group_enter(group)
		let partnerStatusRef = FIRDatabase.database().reference().child("Has-Partner/\(AppState.sharedInstance.userID)")
		partnerStatusRef.observeSingleEventOfType(.Value, withBlock: { partnerStatus in
			if let status = partnerStatus.value as? Bool {
				AppState.sharedInstance.partnerStatus = status
			} else {
				partnerStatusRef.setValue(false)
				AppState.sharedInstance.partnerStatus = false
			}
			dispatch_group_leave(self.group)
		})
	}
	
	// get oneSignal Id
	func oneSignalIdSetup() {
		dispatch_group_enter(group)
		let oneSignalIdRef = FIRDatabase.database().reference().child("FIR-to-OS/\(AppState.sharedInstance.userID)")
		OneSignal.IdsAvailable(){ (userId, pushToken) in
			if (pushToken != nil) {
				NSLog("pushToken:%@", pushToken)
			}
			oneSignalIdRef.setValue(userId)
			dispatch_group_leave(self.group)
		}
		
		/* if firebaes counts setting a value to the same value it was previously as using bandwidth, use this
		oneSignalIdRef.observeSingleEventOfType(.Value, withBlock: { id in
			if id.value as? String == nil {
				OneSignal.IdsAvailable(){ (userId, pushToken) in
					if (pushToken != nil) {
						NSLog("pushToken:%@", pushToken)
					}
					oneSignalIdRef.setValue(userId)
					dispatch_group_leave(group)
				}
			} else {
				dispatch_group_leave(group)
			}
		})*/
	}
	
	// get startDate
	func startDateSetup() {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd Z"

		dispatch_group_enter(group)
		let startDateRef = FIRDatabase.database().reference().child("User-Deadlines/\(AppState.sharedInstance.userID)/Start-Date")
		startDateRef.observeSingleEventOfType(.Value, withBlock: { startDate in
			if let date = startDate.value as? String {
				AppState.sharedInstance.startDate = formatter.dateFromString(date)
			} else {
				startDateRef.setValue(formatter.stringFromDate(NSDate()))
				AppState.sharedInstance.startDate = NSDate()
			}
			dispatch_group_leave(self.group)
		})
	}
}

