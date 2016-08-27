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
	@IBOutlet var titleView: UIView!
	@IBOutlet weak var loadingView: UIView!
	
	// MARK: Properties
	let ref = FIRDatabase.database().reference()
	var storageRef: FIRStorageReference!

	// MARK: UIViewController Lifecycle
	@IBAction func facebookLogin (sender: AnyObject){
		let facebookLogin = FBSDKLoginManager()
		facebookLogin.logOut()
		
		facebookLogin.logInWithReadPermissions(["email", "user_friends"], fromViewController: self, handler:{(facebookResult, facebookError) -> Void in
			if facebookError != nil { print("Facebook login failed. Error \(facebookError)")
			} else if facebookResult.isCancelled { print("Facebook login was cancelled.")
			} else {
				self.loadingView.hidden = false
				let credential = FIRFacebookAuthProvider.credentialWithAccessToken(FBSDKAccessToken.currentAccessToken().tokenString)
				FIRAuth.auth()?.signInWithCredential(credential) { (user, error) in
					if let error = error {
						print(error.localizedDescription)
						return
					}
					self.signedIn(user!)
				}
			}
		})
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		storageRef = FIRStorage.storage().referenceForURL("gs://project-kaerus.appspot.com")
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
		
		// set up firebase for user, if they're new
		isFirstTimeLogin(user!.uid) { (result) -> () in
			result ?
				self.setupForFirstTime() :
				self.performSegueWithIdentifier(self.LoggedIn, sender: nil)
		}
	}
	
	func isFirstTimeLogin(uid: String, completion: (res: Bool)->()) {
		FIRDatabase.database().reference().child("First-Login").child(uid).observeSingleEventOfType(.Value) { (snapshot: FIRDataSnapshot) in
			completion(res: (snapshot.exists() ? false : true)) // if snapshot exists, user is NOT a first timer
		}
	}
}

// all the stuff needed to set up a first-time user
extension LoginViewController {
	func setupForFirstTime() {
		setFirstTimeLogin()
		saveFBInfo()
		setOneSignalId()
		setAllPartnerStuff()
		let startDate = setStartDate()
		let lastPaidDate = setLastPaidDate()
		
		// set AppState
		AppState.sharedInstance.startDate = startDate
		AppState.sharedInstance.lastPaidDate = lastPaidDate
		AppState.sharedInstance.setPartnerState(false,
		                                        f_firstName: nil,
		                                        f_id: nil,
		                                        f_picURL: nil,
		                                        f_fullName: nil,
		                                        f_groupchatId: nil)
		
		let tabBarController = self.storyboard!.instantiateViewControllerWithIdentifier("tabBarController") as! UITabBarController
		self.presentViewController(tabBarController, animated: false, completion: nil)
	}
	
	func setFirstTimeLogin() {
		FIRDatabase.database().reference().child("First-Login").child(AppState.sharedInstance.userID).setValue(false)
	}
	
	func saveFBInfo() {
		// Add user to firebase database, if not already in there
		let graphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields" : "id, first_name, picture.width(200).height(200)"])
		graphRequest.startWithCompletionHandler(){ (connection, result, error) -> Void in
			dispatch_group_enter(self.group)
			if (error != nil) {
				print("Error!", error.localizedDescription)
			} else {
				// fbID needed for FB-to-FIR conversion
				let fbID = result.valueForKey("id") as! String
				// fbID is unique. get this so others can find user by their fb id (when user is looking for a partner)
				self.ref.child("FB-to-FIR").child(fbID).setValue(AppState.sharedInstance.userID)

				// firstName not included in FIRUser object
				AppState.sharedInstance.firstName = result.valueForKey("first_name") as! String
				
				// default picture is too low quality
				let picName = result.valueForKey("picture")?.objectForKey("data")?.objectForKey("url") as! String
				AppState.sharedInstance.photoUrl = NSURL(string: picName)!
				let picData = NSData(contentsOfURL: AppState.sharedInstance.photoUrl)!
				AppState.sharedInstance.photo = UIImage(data: picData)!.circle
				
				let myInfoItem = [
					"firstName" : AppState.sharedInstance.firstName,
					"photoURL" : AppState.sharedInstance.photoUrl.absoluteString
				]
				self.ref.child("My-Info").child(AppState.sharedInstance.userID).setValue(myInfoItem)

				dispatch_group_enter(self.group)
				let profilePicRef = self.storageRef.child("users").child(AppState.sharedInstance.userID).child("profilePic.jpg")
				let uploadTask = profilePicRef.putData(picData, metadata: nil)
				uploadTask.observeStatus(.Success) { snapshot in	// Upload completed successfully
					dispatch_group_leave(self.group)
				}
				uploadTask.observeStatus(.Failure) { snapshot in	// Upload failed
					guard let storageError = snapshot.error else { return }
					guard let errorCode = FIRStorageErrorCode(rawValue: storageError.code) else { return }
					
					switch errorCode {
						case .ObjectNotFound:
							// File doesn't exist
							print("Error! File doesn't exist")
						case .Unauthorized:
							// User doesn't have permission to access file
							print("Error! User doesn't have permission to access file")
						case .Cancelled:
							// User canceled the upload
							print("Error! User cancelled upload")
						case .Unknown:
							// Unknown error occurred, inspect the server response
							print("unknown error")
						default:
							print("default")
					}
					dispatch_group_leave(self.group)
				}
			}
			dispatch_group_leave(self.group)
		}
	}
	
	// set user's oneSignal Id
	func setOneSignalId() {
		dispatch_group_enter(self.group)
		let oneSignalIdRef = FIRDatabase.database().reference().child("FIR-to-OS").child(AppState.sharedInstance.userID)
		OneSignal.IdsAvailable(){ (userId, pushToken) in
			if (pushToken != nil) {
				NSLog("pushToken:%@", pushToken)
			}
			oneSignalIdRef.child(userId).setValue(true)
			dispatch_group_leave(self.group)
		}
	}
	
	// set user's startDate
	func setStartDate() -> NSDate {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd Z"
		let startDateRef = ref.child("User-Deadlines").child(AppState.sharedInstance.userID).child("Start-Date")
		let startDate = formatter.stringFromDate(NSDate())
		startDateRef.setValue(startDate)
		
		return formatter.dateFromString(startDate)!
	}
	
	// set user's lastPaidDate to a far distant past
	func setLastPaidDate() -> NSDate {
		let detailedDateFormatter = NSDateFormatter()
		detailedDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SS"
		detailedDateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
		
		let lastPaidDayRef = ref.child("User-Deadlines/\(AppState.sharedInstance.userID)/Last-Date-Paid")
		let distantPast = NSDate.distantPast()
		lastPaidDayRef.setValue(detailedDateFormatter.stringFromDate(distantPast))
	
		return distantPast
	}
	
	// set partner status. info doesn't need to be set
	func setAllPartnerStuff() {
		let partnerStatusRef = FIRDatabase.database().reference().child("Has-Partner").child(AppState.sharedInstance.userID)
		partnerStatusRef.setValue(false)
	}
}

