//
//  LoadingViewController.swift
//  
//
//  Created by Brandon Chen on 8/24/16.
//
//

import UIKit
import Firebase
import FBSDKCoreKit
import FBSDKLoginKit

class LoadingViewController: UIViewController {

	let group = dispatch_group_create()
	var ref: FIRDatabaseReference!
	var isStartingUp = false // is app loading for the first time? observers use this to avoid leaving a nonexistent group in refs

	var storageRef: FIRStorageReference!
	
	// Note: at this point, we know the user has logged in before and can thus get all their info from Firebase
    override func viewDidLoad() {
		super.viewDidLoad()

		isStartingUp = true
		ref = FIRDatabase.database().reference()
		storageRef = FIRStorage.storage().referenceForURL("gs://project-kaerus.appspot.com")
		
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
			self.presentViewController(tabBarController, animated: false, completion: nil)
		}
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

	func getUserInfo() {
		let myInfoRef = ref.child("My-Info").child(AppState.sharedInstance.userID)
		
		dispatch_group_enter(self.group)
		myInfoRef.observeSingleEventOfType(.Value) { (snapshot: FIRDataSnapshot) in
			let postDict = snapshot.value as! [String : String]
			AppState.sharedInstance.firstName = postDict["firstName"]
			let picName = postDict["photoURL"]!
			AppState.sharedInstance.photoUrl = NSURL(string: picName)!
			let profilePicRef = self.storageRef.child("users").child(AppState.sharedInstance.userID)
			profilePicRef.dataWithMaxSize(1 * 1024 * 1024) { (data, error) -> Void in
				if (error != nil) {
					print("Error!", error?.localizedDescription)
				} else {
					AppState.sharedInstance.photo = UIImage(data: data!)!.circle
				}
				if self.isStartingUp { dispatch_group_leave(self.group) }
			}
		}
	}
	
	// set user's oneSignal Id
	func oneSignalIdSetup() {
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
	
	// get startDate
	func startDateSetup() {
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd Z"

		dispatch_group_enter(group)
		let startDateRef = ref.child("User-Deadlines").child(AppState.sharedInstance.userID).child("Start-Date")
		startDateRef.observeSingleEventOfType(.Value) { (startDate: FIRDataSnapshot) in
			AppState.sharedInstance.startDate = formatter.dateFromString(startDate.value as! String)
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
			AppState.sharedInstance.lastPaidDate = detailedDateFormatter.dateFromString(lastPaidDateSnap.value as! String)
			NSNotificationCenter.defaultCenter().postNotificationName("lastPaidDateChanged", object: nil)
			if self.isStartingUp { dispatch_group_leave(self.group) }
		}
	}
	
	// get partner status
	func partnerStatusSetup() {
		dispatch_group_enter(self.group)
		let partnerStatusRef = ref.child("Has-Partner").child(AppState.sharedInstance.userID)
		partnerStatusRef.observeEventType(.Value) { (partnerStatus: FIRDataSnapshot) in
			AppState.sharedInstance.partnerStatus = partnerStatus.value as! Bool
			NSNotificationCenter.defaultCenter().postNotificationName("hasPartnerChanged", object: nil)
			if self.isStartingUp { dispatch_group_leave(self.group) }
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
			}
			NSNotificationCenter.defaultCenter().postNotificationName("PartnerInfoChanged", object: nil)
			if self.isStartingUp { dispatch_group_leave(self.group) }
		}
	}
	
	// partner OneSignal id is dependant on partner info, so it waits until that finishes loading
	func partnerOneSignalIdSetup() {
		if AppState.sharedInstance.f_firID != nil {
			let oneSignalRef = self.ref.child("FIR-to-OS").child(AppState.sharedInstance.f_firID!)
			if self.isStartingUp { dispatch_group_enter(self.group) }
			
			oneSignalRef.observeEventType(.Value) { (idSnapshot: FIRDataSnapshot) in
				if let id = idSnapshot.value as? String {
					AppState.sharedInstance.f_oneSignalID = id
//					NSNotificationCenter.defaultCenter().postNotificationName("PartnerOSChanged", object: nil)
				} else {
					AppState.sharedInstance.f_oneSignalID = nil
				}
				if self.isStartingUp { dispatch_group_leave(self.group) }
			}
		} 
	}
}
