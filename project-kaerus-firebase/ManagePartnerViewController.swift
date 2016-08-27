//
//  ManageFriendViewController.swift
//  Pods
//
//  Created by Brandon Chen on 7/27/16.
//
//

import UIKit
import FBSDKCoreKit
import Firebase

class ManagePartnerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
	@IBOutlet weak var noPartnerScreen: UIView!
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var partnerScreen: UIView!
	@IBOutlet weak var profilePic: UIImageView!
	@IBOutlet weak var partnerLabel: UILabel!
	@IBOutlet weak var endPartnershipButton: UIButton!
	
	var friendData = [FriendData]()
	var requests = [String : AnyObject]()
	let ref = FIRDatabase.database().reference()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		// if user is looking at this screen the moment PartnerInfo changes, NSNotificationCenter gets activated
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.partnerInfoChanged(_:)), name: "PartnerInfoChanged_Manage", object: nil)
		setScreen()
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	// MARK: set VC screen
	
	func partnerInfoChanged(_: NSNotification) {
		setScreen()
	}
	
	func setScreen() {
		AppState.sharedInstance.partnerStatus == true ? setPartnerScreen() : setNoPartnerScreen()
	}
	
	// set up No Partner screen
	func setNoPartnerScreen() {
		self.title = "Find a Partner"
		partnerScreen.hidden = true
		noPartnerScreen.hidden = false
		setFriendData()
	}
	
	// set up Partner Screen
	func setPartnerScreen() {
		noPartnerScreen.hidden = true
		partnerScreen.hidden = false
		self.title = AppState.sharedInstance.f_firstName
		let friendPhotoData = NSData(contentsOfURL: AppState.sharedInstance.f_photoURL!)!
		profilePic.image = UIImage(data: friendPhotoData)
		profilePic.layer.cornerRadius = profilePic.frame.height / 2
		profilePic.clipsToBounds = true
		partnerLabel.text = "Your partner is:\n\(AppState.sharedInstance.f_name!)"
		endPartnershipButton.layer.cornerRadius = 7
	}
	
	// fills the array 'friendData' with all friends of the user who also have this app
	func setFriendData() {
		friendData.removeAll()
		self.tableView.reloadData()

		let graphRequest : FBSDKGraphRequest = FBSDKGraphRequest(graphPath: "me/friends", parameters: ["fields" : "name, first_name, id, picture.width(200).height(200)"])
		
		// get partner statuses of user
		let myPartnerRequestsRef = FIRDatabase.database().reference().child("Partner-Requests").child(AppState.sharedInstance.userID)
		myPartnerRequestsRef.observeEventType(.Value, withBlock: { snapshot in
			if let partnerStatus = snapshot.value as? [String : AnyObject] {
				self.requests = partnerStatus
			}
		})
		
		graphRequest.startWithCompletionHandler({ (connection, result, error) -> Void in
			if ((error) != nil) {
				print("Error: \(error)")
			} else if let friends = result.valueForKey("data") as? NSArray {
				for friend in friends { // get each friend of user
					let fullName = friend.objectForKey("name") as! String
					let firstName = friend.objectForKey("first_name") as! String
					let fbID = friend.objectForKey("id") as! String
					let picName = friend.objectForKey("picture")?.objectForKey("data")?.objectForKey("url") as! String
					
					// get friend's FIR id
					let FIRIDRef = FIRDatabase.database().reference().child("FB-to-FIR/\(fbID)")
					FIRIDRef.observeEventType(.Value, withBlock: { snapshot in
						let firID = snapshot.value as! String
						
						// get partner status of friend
						let hasPartnerRef = FIRDatabase.database().reference().child("Has-Partner/\(firID)")
						hasPartnerRef.observeEventType(.Value, withBlock: { snapshot in
							let hasPartner = snapshot.value as! Bool
							var fd = FriendData(name: fullName, first_name: firstName, id: firID, picString: picName, partnerStatus: hasPartner)
							
							if let request = self.requests[firID] as? String { // this friend has either partner requested user or vice versa
								fd.whoAsked = request
							}
							self.friendData.append(fd)
							self.tableView.reloadData()
						})
					})
				}
			}
		})
	}
	
	// MARK:- tableView stuff
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return friendData.count
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("FindFriendsTableViewCell", forIndexPath: indexPath) as! FindFriendsTableViewCell
		let friend = friendData[indexPath.row]

		cell.name.text = friend.name
		cell.profilePic.image = friend.pic
		
		cell.profilePic.layer.cornerRadius = cell.profilePic.frame.size.width / 2
		cell.profilePic.clipsToBounds = true
		
		if let status = friend.partnerStatus where status {	// friend already has a partner
			cell.partnerStatus.text = "already has a partner"
		} else if friend.whoAsked == friend.id { // if friend has requested user
			cell.partnerStatus.text = "wants to be your partner!"
			cell.acceptButton.hidden = false
			cell.rejectButton.hidden = false
			cell.acceptButton.tag = indexPath.row
			cell.rejectButton.tag = indexPath.row
		} else { // show send request button
			cell.requestButton.hidden = false
			cell.requestButton.tag = indexPath.row
			if friend.whoAsked == AppState.sharedInstance.userID { // if user has requested friend
				cell.partnerStatus.text = "partner request sent!"
				cell.requestButton.setTitle("Cancel", forState: .Normal)
				cell.requestButton.backgroundColor = UIColor.lightGrayColor()
			} else if friend.whoAsked == "IGNORED" {
				cell.partnerStatus.text = "request ignored. you can still request this partner"
				cell.acceptButton.hidden = true
				cell.rejectButton.hidden = true
			} else {
				cell.partnerStatus.text = ""
			}
		}
		return cell
	}
	
	@IBAction func didPressRequestButton(sender: AnyObject) {
		let friend = friendData[sender.tag!]
		let ref = FIRDatabase.database().reference()
		let setFriendInfoRef = ref.child("Partner-Requests/\(friend.id)/\(AppState.sharedInstance.userID)")
		let setMyInfoRef = ref.child("Partner-Requests/\(AppState.sharedInstance.userID)/\(friend.id)")
		
		if sender.currentTitle == "Request" { // user pressed "request" button
			setFriendInfoRef.setValue(AppState.sharedInstance.userID)
			setMyInfoRef.setValue(AppState.sharedInstance.userID)
			sender.setTitle("Cancel", forState: .Normal)
			(sender as! UIButton).backgroundColor = UIColor.lightGrayColor()
			friendData[sender.tag!].whoAsked = AppState.sharedInstance.userID
			
			FIRDatabase.database().reference().child("FIR-to-OS").child(friend.id).observeSingleEventOfType(.Value) { (snapshot: FIRDataSnapshot) in
				if let id = snapshot.value as? String {
					// send a notification to requested partner
					let msg = AppState.sharedInstance.firstName + " would like to be your partner"
					sendNotification(msg, id: id)
				}
			}
		} else { // user pressed "cancel" button
			setFriendInfoRef.removeValue()
			setMyInfoRef.removeValue()
			sender.setTitle("Request", forState: .Normal)
			(sender as! UIButton).backgroundColor = UIColor(red: 21/255, green: 126/255, blue: 250/255, alpha: 1)
			friendData[sender.tag!].whoAsked = ""
		}
		self.tableView.reloadData()
	}
	
	@IBAction func didPressAcceptButton(sender: AnyObject) {
		let friend = friendData[sender.tag]

		FIRDatabase.database().reference().child("FIR-to-OS").child(friend.id).observeSingleEventOfType(.Value) { (snapshot: FIRDataSnapshot) in
			AppState.sharedInstance.f_oneSignalID = snapshot.value as? String
			let acceptMsg = AppState.sharedInstance.firstName + " has accepted your partner request"
			sendNotification(acceptMsg)
		}
		
		// set group_id. to get group id: 1) sort both ids in alphabetical order. 2) put a “.” sign between the two
		let sortedIds = [AppState.sharedInstance.userID, friend.id].sort()
		let groupchatId = sortedIds[0] + "+" + sortedIds[1]
		
		// update AppState with friend info
		AppState.sharedInstance.setPartnerState(true, f_firstName: friend.first_name, f_id: friend.id, f_picURL: friend.picURL, f_fullName: friend.name, f_groupchatId: groupchatId)
		
		// set both partner statuses to true
		ref.child("Has-Partner").child(friend.id).setValue(true)
		ref.child("Has-Partner").child(AppState.sharedInstance.userID).setValue(true)
		
		// set friend's info dict and send to Firebase
		let friendInfoDict = setFriendInfoDict(AppState.sharedInstance.userID, name: AppState.sharedInstance.name, firstName: AppState.sharedInstance.firstName, picString: AppState.sharedInstance.photoUrl!.absoluteString)
		let setFriendInfoRef = ref.child("Partner-Info").child(AppState.sharedInstance.f_firID!)
		setFriendInfoRef.setValue(friendInfoDict)
		
		// repeat for user
		let myInfoDict = setFriendInfoDict(friend.id, name: friend.name, firstName: friend.first_name, picString: friend.picURL.absoluteString)
		let setMyInfoRef = ref.child("Partner-Info").child(AppState.sharedInstance.userID)
		setMyInfoRef.setValue(myInfoDict)

		// change view
		setPartnerScreen()
	}
	
	func setFriendInfoDict(id: String, name: String, firstName: String, picString: String) -> [String : String] {
		let infoDict = [
			"partner_id" : id,
			"partner_name" : name,
			"partner_firstName" : firstName,
			"partner_pic" : picString,
			"groupchat_id" : AppState.sharedInstance.groupchat_id!
		]
		return infoDict
	}
	
	@IBAction func didPressRejectButton(sender: AnyObject) {
		let friend = friendData[sender.tag]
		friendData[sender.tag].whoAsked = "IGNORED"
		let partnerRequestRef = ref.child("Partner-Requests/\(AppState.sharedInstance.userID)/\(friend.id)")
		partnerRequestRef.removeValue()
		self.tableView.reloadData()
	}
	
	@IBAction func didPressEndPartnershipButton(sender: AnyObject) {
		// Set both users' Has-Partner to false
		ref.child("Has-Partner").child(AppState.sharedInstance.f_firID!).setValue(false)
		ref.child("Has-Partner").child(AppState.sharedInstance.userID).setValue(false)
		
		// Inform user's former partner
		let endPartnershipMessage = AppState.sharedInstance.firstName + " has ended your partnership"
		sendNotification(endPartnershipMessage)
		
		// Remove Partner-Info for both users
		let setFriendInfoRef = ref.child("Partner-Info").child(AppState.sharedInstance.f_firID!)
		let setMyInfoRef = ref.child("Partner-Info").child(AppState.sharedInstance.userID)
		setFriendInfoRef.removeValue()
		setMyInfoRef.removeValue()
		
		// Remove Partner-Requests for both users
		let friendPartnerRequestRef = ref.child("Partner-Requests").child(AppState.sharedInstance.f_firID!).child(AppState.sharedInstance.userID)
		friendPartnerRequestRef.removeValue()
		let myPartnerRequestRef = ref.child("Partner-Requests").child(AppState.sharedInstance.userID).child(AppState.sharedInstance.f_firID!)
		myPartnerRequestRef.removeValue()

		// reset AppState friend values
		AppState.sharedInstance.setPartnerState(false, f_firstName: nil, f_id: nil, f_picURL: nil, f_fullName: nil, f_groupchatId: nil)
		AppState.sharedInstance.f_oneSignalID = nil
		
//		setNoPartnerScreen()
	}
}
