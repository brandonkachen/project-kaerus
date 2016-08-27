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
//	@IBOutlet var titleView: UIView!
	@IBOutlet weak var splashScreen: UIView!
	
	// MARK: Properties
	let ref = FIRDatabase.database().reference()
	var storageRef: FIRStorageReference!
	var isStartingUp = false

	// MARK: Helper functions for entering and leaving dispatch group
	func enterGroup() {
		if self.isStartingUp { dispatch_group_enter(self.group) }
	}
	
	func leaveGroup() {
		if self.isStartingUp { dispatch_group_leave(self.group) }
	}
	
	// MARK: UIViewController Lifecycle
	@IBAction func facebookLogin (sender: AnyObject){
		let facebookLogin = FBSDKLoginManager()
		facebookLogin.logOut()
		
		facebookLogin.logInWithReadPermissions(["email", "user_friends"], fromViewController: self, handler:{(facebookResult, facebookError) -> Void in
			if facebookError != nil { print("Facebook login failed. Error \(facebookError)")
			} else if facebookResult.isCancelled { print("Facebook login was cancelled.")
			} else {
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
		})
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		storageRef = FIRStorage.storage().referenceForURL("gs://project-kaerus.appspot.com")
		
		self.splashScreen.hidden = false
		isStartingUp = true
		
		let user = FIRAuth.auth()?.currentUser
		if user != nil { // user is logged in so load their info
			AppState.sharedInstance.setState(user)
			MeasurementHelper.sendLoginEvent()
			NSNotificationCenter.defaultCenter().postNotificationName(Constants.NotificationKeys.SignedIn, object: nil, userInfo: nil)
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
	
		// set AppState values
		getUserInfo()
		oneSignalIdSetup()
		startDateSetup()
		
		// keep observers on these, in case they change
		lastPaidDaySetup()
		partnerStatusSetup()
		partnerInfoSetup()
		
		// when everything is loaded, go to DeadlineViewController
		dispatch_group_notify(group, dispatch_get_main_queue()) {
			self.isStartingUp = false
			
			let tabBarController = self.storyboard!.instantiateViewControllerWithIdentifier("tabBarController") as! UITabBarController
//			tabBarController.selectedIndex = 1
			self.presentViewController(tabBarController, animated: false, completion: nil)
		}
	}
}

extension LoginViewController {
	func getUserInfo() {
		let myInfoRef = ref.child("My-Info").child(AppState.sharedInstance.userID)
		
		dispatch_group_enter(self.group)
		myInfoRef.observeSingleEventOfType(.Value) { (snapshot: FIRDataSnapshot) in
			if let postDict = snapshot.value as? [String : String] {
				self.setReturningUserInfo(postDict)
			} else {
				self.setNewUserInfo()
			}
			self.leaveGroup()
		}
	}
	
	func setReturningUserInfo(postDict: [String : String]) {
		AppState.sharedInstance.firstName = postDict["firstName"]
		let picName = postDict["photoURL"]!
		AppState.sharedInstance.photoUrl = NSURL(string: picName)!
		let profilePicRef = self.storageRef.child("users").child(AppState.sharedInstance.userID).child("profilePic.jpg")
		profilePicRef.dataWithMaxSize(1 * 1024 * 1024) { (data, error) -> Void in
			if self.isStartingUp { dispatch_group_enter(self.group) }
			if (error != nil) {
				print("Error!", error?.localizedDescription)
			} else {
				AppState.sharedInstance.photo = UIImage(data: data!)!.circle
			}
			self.leaveGroup()
		}
	}
	
	func setNewUserInfo() {
		self.enterGroup()
		let graphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields" : "id, first_name, picture.width(200).height(200)"])
		graphRequest.startWithCompletionHandler(){ (connection, result, error) -> Void in
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
				
				// upload facebook profile pic to Firebase
				self.uploadProfilePic(picData)
			}
			self.leaveGroup()
		}
	}
	
	func uploadProfilePic(picData: NSData) {
		self.enterGroup()
		let profilePicRef = self.storageRef.child("users").child(AppState.sharedInstance.userID).child("profilePic.jpg")
		let uploadProfilePicTask = profilePicRef.putData(picData, metadata: nil)
		
		// either one of the following will be called:
		
		// Upload completed successfully
		uploadProfilePicTask.observeStatus(.Success) { snapshot in
			self.leaveGroup()
		}
		
		// Upload failed
		uploadProfilePicTask.observeStatus(.Failure) { snapshot in
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
				break
			}
			self.leaveGroup()
		}
	}
	
	//TODO: figure out whether to use childByAutoId or just the oneSignalId for key
	// set user's oneSignal Id
	func oneSignalIdSetup() {
		dispatch_group_enter(self.group)
		let oneSignalIdRef = FIRDatabase.database().reference().child("FIR-to-OS").child(AppState.sharedInstance.userID)
		OneSignal.IdsAvailable(){ (userId, pushToken) in
			if (pushToken != nil) {
				NSLog("pushToken:%@", pushToken)
			}
			oneSignalIdRef.childByAutoId().setValue(userId)
			dispatch_group_leave(self.group)
		}
	}
	
	// get startDate
	func startDateSetup() {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd Z"
		
		dispatch_group_enter(group)
		let startDateRef = ref.child("User-Deadlines").child(AppState.sharedInstance.userID).child("Start-Date")
		startDateRef.observeSingleEventOfType(.Value) { (startDateSnap: FIRDataSnapshot) in
			if let startDate = startDateSnap.value as? String {
				AppState.sharedInstance.startDate = formatter.dateFromString(startDate)
			} else {
				let startDate = formatter.stringFromDate(NSDate())
				startDateRef.setValue(startDate)
			}
			dispatch_group_leave(self.group)
		}
	}
	
	func lastPaidDaySetup() {
		let detailedDateFormatter = NSDateFormatter()
		detailedDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SS"
		detailedDateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
		
		dispatch_group_enter(self.group)
		let lastPaidDayRef = ref.child("User-Deadlines").child(AppState.sharedInstance.userID).child("Last-Date-Paid")
		lastPaidDayRef.observeEventType(.Value) { (lastPaidDateSnap: FIRDataSnapshot) in
			if let lastPaidDate = lastPaidDateSnap.value as? String {
				AppState.sharedInstance.lastPaidDate = detailedDateFormatter.dateFromString(lastPaidDate)
				NSNotificationCenter.defaultCenter().postNotificationName("lastPaidDateChanged", object: nil)
			} else {
				let distantPast = NSDate.distantPast()
				lastPaidDayRef.setValue(detailedDateFormatter.stringFromDate(distantPast))
			}
			self.leaveGroup()
		}
	}
	
	// get partner status
	func partnerStatusSetup() {
		dispatch_group_enter(self.group)
		let partnerStatusRef = ref.child("Has-Partner").child(AppState.sharedInstance.userID)
		partnerStatusRef.observeEventType(.Value) { (partnerStatusSnap: FIRDataSnapshot) in
			if let status = partnerStatusSnap.value as? Bool {
				AppState.sharedInstance.partnerStatus = status
				NSNotificationCenter.defaultCenter().postNotificationName("hasPartnerChanged", object: nil)
			} else {
				partnerStatusRef.setValue(false)
			}
			self.leaveGroup()
		}
	}
	
	// get partner's info
	func partnerInfoSetup() {
		dispatch_group_enter(self.group)
		let partnerInfoRef = ref.child("Partner-Info").child(AppState.sharedInstance.userID)
		partnerInfoRef.observeEventType(.Value) { (partnerInfoSnapshot: FIRDataSnapshot) in
			if let partnerInfoDict = partnerInfoSnapshot.value as? [String : String] {
				AppState.sharedInstance.setPartnerState(true,
				                                        f_firstName: partnerInfoDict["partner_firstName"],
				                                        f_id: partnerInfoDict["partner_id"],
				                                        f_picURL: NSURL(string: partnerInfoDict["partner_pic"]!),
				                                        f_fullName: partnerInfoDict["partner_name"],
				                                        f_groupchatId: partnerInfoDict["groupchat_id"])
				self.partnerOneSignalIdSetup()
			} else {
				AppState.sharedInstance.setPartnerState(false,
				                                        f_firstName: nil,
				                                        f_id: nil,
				                                        f_picURL: nil,
				                                        f_fullName: nil,
				                                        f_groupchatId: nil)
				AppState.sharedInstance.f_oneSignalID = nil
			}
			// notifies 3 VCs, in case user is looking at any one of them
			NSNotificationCenter.defaultCenter().postNotificationName("PartnerInfoChanged_Manage", object: nil)
			NSNotificationCenter.defaultCenter().postNotificationName("PartnerInfoChanged_Deadlines", object: nil)
			NSNotificationCenter.defaultCenter().postNotificationName("PartnerInfoChanged_Chat", object: nil)
			self.leaveGroup()
		}
	}
	
	// partner OneSignal id is dependant on partner info, so it waits until that finishes loading
	func partnerOneSignalIdSetup() {
		self.enterGroup()

		let oneSignalRef = self.ref.child("FIR-to-OS").child(AppState.sharedInstance.f_firID!)
		oneSignalRef.observeEventType(.Value) { (idSnapshot: FIRDataSnapshot) in
			if let id = idSnapshot.value as? String {
				AppState.sharedInstance.f_oneSignalID = id
//					NSNotificationCenter.defaultCenter().postNotificationName("PartnerOSChanged", object: nil)
			} else {
				AppState.sharedInstance.f_oneSignalID = nil
			}
			self.leaveGroup()
		}
	}
}


/*

// all the stuff needed to load or set up user info
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
		
//		let tabBarController = self.storyboard!.instantiateViewControllerWithIdentifier("tabBarController") as! UITabBarController
//		self.presentViewController(tabBarController, animated: false, completion: nil)
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
				
				// either one of the following will be called
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
							break
					}
					dispatch_group_leave(self.group)
				}
			}
			dispatch_group_leave(self.group)
		}
	}
}

*/
