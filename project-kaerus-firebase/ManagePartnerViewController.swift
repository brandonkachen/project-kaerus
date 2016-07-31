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
	@IBOutlet weak var searchBar: UISearchBar!
	@IBOutlet weak var tableView: UITableView!
	
	@IBOutlet weak var partnerScreen: UIView!
	@IBOutlet weak var profilePic: UIImageView!
	@IBOutlet weak var partnerLabel: UILabel!
	@IBOutlet weak var endPartnershipButton: UIButton!
	
	var searchActive : Bool = false
	var friendData = [FriendData]()
	var filteredFriendData = [FriendData]()
	var requests = [String : AnyObject]()
	let ref = FIRDatabase.database().reference()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self
		searchBar.delegate = self
		
		// Determine if user has a friend or not
		if AppState.sharedInstance.partnerStatus == true {
			setPartnerScreen()
		} else { // user doesn't have a friend
			self.title = "Find Partner"
			partnerScreen.hidden = true
			setFriendData()
		}
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
		endPartnershipButton.layer.cornerRadius = 5
	}
	
	func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
		searchActive = true
	}
	
	func searchBarTextDidEndEditing(searchBar: UISearchBar) {
		searchActive = false
	}
	
	func searchBarCancelButtonClicked(searchBar: UISearchBar) {
		searchActive = false
	}
	
	func searchBarSearchButtonClicked(searchBar: UISearchBar) {
		searchActive = false
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	// fills the array 'friendData' with all friends of the user who also have this app
	func setFriendData() {
		friendData.removeAll()

		let graphRequest : FBSDKGraphRequest = FBSDKGraphRequest(graphPath: "me/friends", parameters: ["fields" : "name, first_name, id, picture.width(200).height(200)"])
		
		// get partner statuses of user
		let myPartnerRequestsRef = FIRDatabase.database().reference().child("Partner-Requests/\(AppState.sharedInstance.userID)")
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
		return searchActive ? filteredFriendData.count : friendData.count
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("FindFriendsTableViewCell", forIndexPath: indexPath) as! FindFriendsTableViewCell
		let friend = friendData[indexPath.row]

		if searchActive { // filtered data
			
		} else { // all data
			cell.name.text = friend.name
			cell.profilePic.image = friend.pic
			
			cell.profilePic.layer.cornerRadius = cell.profilePic.frame.size.width / 2
			cell.profilePic.clipsToBounds = true
//			cell.profilePic.layer.borderWidth = 3.0
//			cell.profilePic.layer.borderColor = UIColor.blackColor().CGColor
			
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
		
		// update AppState with friend info
		AppState.sharedInstance.partnerStatus = true
		AppState.sharedInstance.f_name = friend.name
		AppState.sharedInstance.f_firstName = friend.first_name
		AppState.sharedInstance.f_firID = friend.id
		AppState.sharedInstance.f_photoURL = friend.picURL
		
		// set group_id. to get group id: 1) sort both ids in alphabetical order. 2) put a “.” sign between the two
		let sortedIds = [AppState.sharedInstance.userID, AppState.sharedInstance.f_firID!].sort()
		AppState.sharedInstance.groupchat_id = sortedIds[0] + "+" + sortedIds[1]
		
		// set both partner statuses to true
		ref.child("Has-Partner/\(friend.id)").setValue(true)
		ref.child("Has-Partner/\(AppState.sharedInstance.userID)").setValue(true)
		
		// set both friend-info
		// set friend info
		let friend_info = [
			"friend_id" : AppState.sharedInstance.userID,
			"friend_name" : AppState.sharedInstance.username,
			"friend_firstName" : AppState.sharedInstance.firstName,
			"friend_pic" : AppState.sharedInstance.photoUrl!.absoluteString,
			"groupchat_id" : AppState.sharedInstance.groupchat_id!
		]
		let setFriendInfoRef = ref.child("Friend-Info/\(AppState.sharedInstance.f_firID!)")
		setFriendInfoRef.setValue(friend_info)
		
		// set user's info
		let my_info = [
			"friend_id" : friend.id,
			"friend_name" : friend.name,
			"friend_firstName" : friend.first_name,
			"friend_pic" : friend.picURL.absoluteString,
			"groupchat_id" : AppState.sharedInstance.groupchat_id!
		]
		let setMyInfoRef = ref.child("Friend-Info/\(AppState.sharedInstance.userID)")
		setMyInfoRef.setValue(my_info)
		
		// change view
		setPartnerScreen()
	}
	
	@IBAction func didPressRejectButton(sender: AnyObject) {
		let friend = friendData[sender.tag]
		friendData[sender.tag].whoAsked = "IGNORED"
		let partnerRequestRef = ref.child("Partner-Requests/\(AppState.sharedInstance.userID)/\(friend.id)")
		partnerRequestRef.removeValue()
		self.tableView.reloadData()
	}
}