//
//  SettingsTableViewController.swift
//
//  Created by Brandon Chen on 7/16/16.
//
//

import UIKit
import FirebaseAuth
import FirebaseDatabase

class SettingsTableViewController: UITableViewController {
	
	var savedSelectedIndexPath: NSIndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		self.savedSelectedIndexPath = nil
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		if let indexPath = self.savedSelectedIndexPath {
			self.tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: .None)
		}
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.savedSelectedIndexPath = tableView.indexPathForSelectedRow
		if let indexPath = self.savedSelectedIndexPath {
			self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
		}
	}
	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
		if indexPath.section == 0 || indexPath.section == 3 || AppState.sharedInstance.groupchat_id != nil {
			return indexPath
		} else {
			return nil
		}
	}
	
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if indexPath.section == 3 {
			let email = "projectkaerus@gmail.com"
			let url = NSURL(string: "mailto:\(email)")!
			UIApplication.sharedApplication().openURL(url)
		}
	}
	
	
	// MARK:- sign out
	
	@IBAction func signOut(sender: AnyObject) {
		let firebaseAuth = FIRAuth.auth()
		do {
			try firebaseAuth?.signOut()
			AppState.sharedInstance.signedIn = false
			// reset AppState's friend data, so if next user doesn't have a partner, they don't get this user's partner info
			AppState.sharedInstance.setPartnerState(false,
				                f_firstName: nil,
				                f_id: nil,
								f_fullName: nil,
								f_groupchatId: nil)
			AppState.sharedInstance.f_photo = nil
			AppState.sharedInstance.f_oneSignalID = nil
			
			let group = dispatch_group_create()
			var osId: String!
			dispatch_group_enter(group)
			OneSignal.IdsAvailable() { (userId, pushToken) in
				if (pushToken != nil) {
					NSLog("pushToken:%@", pushToken)
				}
				osId = userId
				dispatch_group_leave(group)
			}
			
			dispatch_group_notify(group, dispatch_get_main_queue()) {
				let oneSignalRef = FIRDatabase.database().reference().child("FIR-to-OS").child(AppState.sharedInstance.userID).child(osId)
				oneSignalRef.removeValue()
				
				let loginScreenViewController = self.storyboard!.instantiateViewControllerWithIdentifier("loginViewController") as! LoginViewController
				self.presentViewController(loginScreenViewController, animated: true, completion: nil)
			}
		} catch let signOutError as NSError {
			print ("Error signing out: \(signOutError)")
		}
	}
}
