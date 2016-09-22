//
//  LoadingViewController.swift
//  
//
//  Created by Brandon Chen on 8/24/16.
//
//

import UIKit
import Firebase
import FirebaseStorage
import FBSDKCoreKit
import FBSDKLoginKit

class LoadingViewController: UIViewController {
	let group = dispatch_group_create()
	var ref: FIRDatabaseReference!
	var storageRef: FIRStorageReference!
	var user: FIRUser!
	var isStartingUp = false // is app loading for the first time? observers use this to avoid leaving a nonexistent group in refs
	var selectedIndex = 0
	
	// Helper functions for entering and leaving dispatch group
	func enterGroup() { if isStartingUp { dispatch_group_enter(self.group) } }
	func leaveGroup() { if isStartingUp { dispatch_group_leave(self.group) } }
		
    override func viewDidLoad() {
		super.viewDidLoad()
		
		isStartingUp = true
		ref = FIRDatabase.database().reference()
		storageRef = FIRStorage.storage().referenceForURL("gs://project-kaerus.appspot.com")
		
		if let user = user { // came from AppDelegate, so we already have the user
			self.signedIn(user)
		} else { // came from LoginViewController, so we need to authenticate with Firebase first
			let credential = FIRFacebookAuthProvider.credentialWithAccessToken(FBSDKAccessToken.currentAccessToken().tokenString)
			FIRAuth.auth()?.signInWithCredential(credential) { (user, error) in
				if let error = error {
					print(error.localizedDescription)
					self.performSegueWithIdentifier("LoggedIn", sender: nil)
				}
				self.signedIn(user!)
			}
		}
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	func signedIn(user: FIRUser) {
		AppState.sharedInstance.setState(user)
		MeasurementHelper.sendLoginEvent()
		NSNotificationCenter.defaultCenter().postNotificationName(Constants.NotificationKeys.SignedIn, object: nil, userInfo: nil)
		
		// set AppState values
		getUserInfo()
		oneSignalIdSetup()
		startDateSetup()
		
		// keep observers on these, in case they change
		partnerStatusSetup()
		partnerInfoSetup()
		
		// when everything is loaded, go to DeadlineViewController
		dispatch_group_notify(group, dispatch_get_main_queue()) {
			self.isStartingUp = false
			let tabBarController = self.storyboard!.instantiateViewControllerWithIdentifier("tabBarController") as! UITabBarController
			tabBarController.selectedIndex = self.selectedIndex
			self.presentViewController(tabBarController, animated: false, completion: nil)
		}
	}
}

// all functions used to sign in
extension LoadingViewController {
	func getUserInfo() {
		let myInfoRef = ref.child("My-Info").child(AppState.sharedInstance.userID)
		
		dispatch_group_enter(self.group)
		myInfoRef.observeSingleEventOfType(.Value) { (snapshot: FIRDataSnapshot) in
			if let postDict = snapshot.value as? [String : String] {
				self.setReturningUserInfo(postDict)
			} else {
				self.setNewUserInfo()
			}
			OneSignal.registerForPushNotifications()
			self.leaveGroup()
		}
	}
	
	func setReturningUserInfo(postDict: [String : String]) {
		self.enterGroup()
		AppState.sharedInstance.firstName = postDict["firstName"]
		let profilePicRef = self.storageRef.child("users").child(AppState.sharedInstance.userID).child("profilePic.jpg")
		profilePicRef.dataWithMaxSize(1 * 1024 * 1024) { (data, error) -> Void in
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
				let photoUrl = NSURL(string: picName)!
				let picData = NSData(contentsOfURL: photoUrl)!
				AppState.sharedInstance.photo = UIImage(data: picData)!.circle
				
				self.ref.child("My-Info").child(AppState.sharedInstance.userID).child("firstName").setValue(AppState.sharedInstance.firstName)
				
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
	
	// set user's oneSignal Id
	func oneSignalIdSetup() {
		dispatch_group_enter(self.group)
		let oneSignalIdRef = ref.child("FIR-to-OS").child(AppState.sharedInstance.userID)
		OneSignal.IdsAvailable(){ (userId, pushToken) in
			if (pushToken != nil) {
				NSLog("pushToken:%@", pushToken)
			}
			oneSignalIdRef.setValue(userId)
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
				AppState.sharedInstance.startDate = formatter.dateFromString(startDate)
			}
			dispatch_group_leave(self.group)
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
			let partnerSetupGroup = dispatch_group_create() // used for functions partnerProfilePicSetup

			if let partnerInfoDict = partnerInfoSnapshot.value as? [String : String] {
				AppState.sharedInstance.setPartnerState(true,
				                                        f_firstName: partnerInfoDict["partner_firstName"],
				                                        f_id: partnerInfoDict["partner_id"],
				                                        f_fullName: partnerInfoDict["partner_name"],
				                                        f_groupchatId: partnerInfoDict["groupchat_id"])
				
				self.partnerOneSignalIdSetup(partnerSetupGroup)
				self.partnerProfilePicSetup(partnerSetupGroup)
				self.paymentSettingsSetup(partnerSetupGroup)
//				self.badgesSetup()
			} else {
				AppState.sharedInstance.setPartnerState(false,
				                                        f_firstName: nil,
				                                        f_id: nil,
				                                        f_fullName: nil,
				                                        f_groupchatId: nil)
				AppState.sharedInstance.f_photo = nil
				AppState.sharedInstance.f_oneSignalID = nil
			}
			
			dispatch_group_notify(partnerSetupGroup, dispatch_get_main_queue()) {
				// notifies 3 VCs, in case user is looking at any one of them
				NSNotificationCenter.defaultCenter().postNotificationName("PartnerInfoChanged_Manage", object: nil)
				NSNotificationCenter.defaultCenter().postNotificationName("PartnerInfoChanged_Deadlines", object: nil)
				NSNotificationCenter.defaultCenter().postNotificationName("PartnerInfoChanged_Chat", object: nil)
				self.leaveGroup()
			}
		}
	}
	
	func partnerProfilePicSetup(group: dispatch_group_t) {
		dispatch_group_enter(group)
		let partnerProfilePicRef = self.storageRef.child("users").child(AppState.sharedInstance.f_firID!).child("profilePic.jpg")
		partnerProfilePicRef.dataWithMaxSize(1 * 1024 * 1024) { (data, error) -> Void in
			if (error != nil) {
				print("Error!", error?.localizedDescription)
			} else {
				AppState.sharedInstance.f_photo = UIImage(data: data!)!.circle
			}
			if self.isStartingUp { dispatch_group_leave(group) }
		}
	}
	
	// partner OneSignal id depends on partner info, so it waits until that finishes loading
	func partnerOneSignalIdSetup(group: dispatch_group_t) {
		dispatch_group_enter(group)
		let oneSignalRef = self.ref.child("FIR-to-OS").child(AppState.sharedInstance.f_firID!)
		oneSignalRef.observeEventType(.Value) { (idSnapshot: FIRDataSnapshot) in
			AppState.sharedInstance.f_oneSignalID = idSnapshot.value as? String
			NSNotificationCenter.defaultCenter().postNotificationName("PartnerOneSignalChanged", object: nil)
			if self.isStartingUp { dispatch_group_leave(group) }
		}
	}
	
	func paymentSettingsSetup(group: dispatch_group_t) {
		dispatch_group_enter(group)
		let paymentSettingsRef = self.ref.child("Payments").child(AppState.sharedInstance.groupchat_id!).child("Settings")
		paymentSettingsRef.observeEventType(.Value) { (paymentSettingsSnapshot: FIRDataSnapshot) in
			let paymentsDict = paymentSettingsSnapshot.value as! [String : AnyObject]
			let AS = AppState.sharedInstance
			AS.costOfEachDay = paymentsDict["Cost-Per-Day"] as! Double
			AS.maxLimit = paymentsDict["Max-Limit"] as! Double
			AS.splitCost = paymentsDict["Split-Cost"] as! Bool
			AS.flatRate = (paymentsDict as NSDictionary).valueForKeyPath("Flat-Rate.Enabled") as! Bool
			AS.flatRate_EachDeadlineCost = (paymentsDict as NSDictionary).valueForKeyPath("Flat-Rate.Each-Deadline-Cost") as! Double
			AS.flatRate_AfterNumDeadlines = (paymentsDict as NSDictionary).valueForKeyPath("Flat-Rate.After-Num-Deadlines") as! Int
			NSNotificationCenter.defaultCenter().postNotificationName("PaymentSettingsChanged", object: nil)
			if self.isStartingUp { dispatch_group_leave(group) }
		}
	}
	
//	func badgesSetup() {
//		self.enterGroup()
//		let badgesRef = self.ref.child("Badges").child(AppState.sharedInstance.userID)
//		badgesRef.observeEventType(.Value) { (snapshot: FIRDataSnapshot!) in
//			if let unseenMessages = snapshot.childSnapshotForPath("Unseen-Messages").value as? Int {
//				AppState.sharedInstance.unseenMessagesCount = unseenMessages
//				NSNotificationCenter.defaultCenter().postNotificationName("MyBadgesChanged", object: nil)
//			} else {
//				AppState.sharedInstance.unseenMessagesCount = 0
//			}
//		}
//	}
}
