//
//  RespondToRequestViewController.swift
//  Pods
//
//  Created by Brandon Chen on 7/19/16.
//
//

import UIKit
import FirebaseDatabase

class RespondToRequestViewController: UIViewController {

	@IBOutlet weak var requestText: UILabel!
	@IBOutlet weak var yesButton: UIButton!
	@IBOutlet weak var noButton: UIButton!
	
	// used to hold friend data before storing away in AppState if partnership is forged
	var f_name : String?
	var f_id : String?
	var f_picURL : NSURL?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		checkPartnerRequest()
		
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	@IBAction func didPressConfirmButton(sender: AnyObject) {
		confirmOrDeny(true)
		
		requestText.text = "You and \(f_name!) are partners now!"
		yesButton.hidden = true
		noButton.hidden = true
	}
	
	@IBAction func didPressDenyButton(sender: AnyObject) {
		confirmOrDeny(false)
		
		yesButton.hidden = true
		noButton.hidden = true
	}
	
	// check for friend requests
	func checkPartnerRequest() {
		let getIdRef = FIRDatabase.database().reference().child("User-Friend-Info/\(AppState.sharedInstance.userID!)")
		getIdRef.observeEventType(FIRDataEventType.Value, withBlock: { (snapshot) in
			if let postDict = snapshot.value as? [String : AnyObject] {
				let friend_status = postDict["friend_status"] as! String
				if friend_status == "PENDING" {
					let friend_name = postDict["friend_name"] as! String
					self.f_name = friend_name
					
					let friend_id = postDict["friend_id"] as! String
					self.f_id = friend_id
					
					let friend_pic = postDict["friend_pic"] as! String
					self.f_picURL = NSURL(string: friend_pic)
					
					let text = "\(friend_name) wants to be your partner. Do you accept this partnership?"
					self.requestText.text = text
				}
			}
		})
	}
	
	// confirm or deny partnership
	func confirmOrDeny(partner: Bool) {
		let getIdRef = FIRDatabase.database().reference().child("User-Friend-Info")
		let val = partner ? "FRIEND" : "NOT FRIEND"

		// set your friend's partner value
		let getFriendIdRef = getIdRef.child("\(self.f_id!)")
		getFriendIdRef.child("friend_status").setValue(val)

		// set your own partner value
		let getMyIdRef = getIdRef.child("\(AppState.sharedInstance.userID!)")
		getMyIdRef.child("friend_status").setValue(val)
		
		// set up AppState info and assign a groupchat id
		if partner == true {
			AppState.sharedInstance.friend_status = val
			AppState.sharedInstance.f_displayName = self.f_name
			AppState.sharedInstance.f_FIRid = self.f_id
			AppState.sharedInstance.f_photoURL = self.f_picURL
			
			// to get group id: 1) sort both ids in alphabetical order. 2) put a “.” sign between the two
			let sortedIds = [AppState.sharedInstance.userID!, AppState.sharedInstance.f_FIRid!].sort()
			let chat_id = sortedIds[0] + "+" + sortedIds[1]
			print(chat_id)

			AppState.sharedInstance.groupchat_id = chat_id
			
			// set groupchat id in both user's info
			getFriendIdRef.child("groupchat_id").setValue(chat_id)
			getMyIdRef.child("groupchat_id").setValue(chat_id)
		}
	}

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
