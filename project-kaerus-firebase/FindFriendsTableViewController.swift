//
//  FindFriendsTableViewController.swift
//  Pods
//
//  Created by Brandon Chen on 7/18/16.
//
//

import UIKit
import FBSDKCoreKit
import FirebaseDatabase

class FindFriendsTableViewController: UITableViewController {

	@IBOutlet weak var searchBar: UISearchBar!
	var searchActive = false
	var friendData = [FriendData]()
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
		
		getFriendData()
    }
	
	func getFriendData() {
		let graphRequest : FBSDKGraphRequest = FBSDKGraphRequest(graphPath: "me/friends?limit=999", parameters: ["fields" : "name, first_name, id, picture.type(square)"])
		
		graphRequest.startWithCompletionHandler({ (connection, result, error) -> Void in
			if ((error) != nil) {
				print("Error: \(error)")
			} else {
				if let friends = result.valueForKey("data") as? NSArray {
					for friend in friends { // get each friend of user
						let fullName = friend.objectForKey("name") as! String
						let firstName = friend.objectForKey("first_name") as! String
						let fbID = friend.objectForKey("id") as! String
						let picName = friend.objectForKey("picture")?.objectForKey("data")?.objectForKey("url") as! String
						
						let fd = FriendData(name: fullName, first_name: firstName, id: fbID, picString: picName)
						self.friendData.append(fd)
					}
				}
			}
			self.tableView.reloadData()
		})
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendData.count
    }

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cellIdentifier = "FindFriendsTableViewCell"
		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! FindFriendsTableViewCell
		cell.name.text = friendData[indexPath.row].first_name
		cell.profilePic.image = friendData[indexPath.row].pic
		cell.requestButton.tag = indexPath.row
		return cell
    }

	
	// MARK:- Search Bar Active
	
	func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
		self.searchActive = true
	}
	
	func searchBarTextDidEndEditing(searchBar: UISearchBar) {
		self.searchActive = false
	}
	
	func searchBarCancelButtonClicked(searchBar: UISearchBar) {
		self.searchActive = false
	}
	
	func searchBarSearchButtonClicked(searchBar: UISearchBar) {
		self.searchActive = false
	}
	
	@IBAction func didPressRequestButton(sender: AnyObject) {
		let row = sender.tag
		let indexPath = NSIndexPath(forRow: row, inSection: 0)
		
		let cell = tableView.cellForRowAtIndexPath(indexPath) as! FindFriendsTableViewCell
		
		if cell.requestButton.currentTitle == "Send Partner Request" {
			// user pressed "send partner request"
			let fbID = friendData[row].id
			let ref = FIRDatabase.database().reference()
			
			let getIdRef = ref.child("FB-to-FIR/\(fbID)")
			getIdRef.observeEventType(FIRDataEventType.Value, withBlock: { (snapshot) in
				let postDict = snapshot.value as! [String : AnyObject]
				if let fir_id: String = postDict["FIR-ID"] as? String {
					// set friend info. for now, this simply overwrites any existing data :/
					// TODO: check if friend_status is already pending or not!
					
					// set friend info
					let friend_info = [
						"friend_status" : "PENDING",
						"friend_id" : AppState.sharedInstance.userID!,
						"friend_name" : AppState.sharedInstance.username!,
						"friend_pic" : AppState.sharedInstance.photoUrl!.absoluteString,
						"groupchat_id" : ""
					]
					let setFriendInfoRef = ref.child("User-Friend-Info/\(fir_id)")
					setFriendInfoRef.setValue(friend_info)
					
					// now set user's info
					let my_info = [
						"friend_status" : "ASKING",
						"friend_id" : fir_id,
						"friend_name" : self.friendData[row].name,
						"friend_pic" : self.friendData[row].picURL.absoluteString,
						"groupchat_id" : ""
					]
					let setMyInfoRef = ref.child("User-Friend-Info/\(AppState.sharedInstance.userID!)")
					setMyInfoRef.setValue(my_info)
				} else { // friend not in database, error!
					print("error")
				}
				cell.requestButton.setTitle("Cancel Request", forState: .Normal)
			})
		} else {
			// user pressed "cancel request"
			cell.requestButton.setTitle("Send Partner Request", forState: .Normal)
		}
		
	}
	
    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
