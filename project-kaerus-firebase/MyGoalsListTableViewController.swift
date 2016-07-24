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

class GoalsTableViewController: UITableViewController {
  // MARK: Constants
	let ListToUsers = "ListToUsers"
	
	
  // MARK: Properties
	var items = [Goal]()
	var masterRef, deadlinesRef, dayUserLastSawRef: FIRDatabaseReference!
	private var _refHandle: FIRDatabaseHandle!
	var dayUserIsLookingAt = 1 // defaults to 1, but is set by the 'day' variable in User-Goals
	var userWhoseDeadlinesAreShown = AppState.sharedInstance.userID!
	
	var storageRef: FIRStorageReference!

	@IBOutlet weak var segmentedControl: UISegmentedControl!
	@IBOutlet weak var addDeadlineButton: UIBarButtonItem!
	@IBOutlet weak var backwardOneDay: UIBarButtonItem!
	@IBOutlet weak var forwardOneDay: UIBarButtonItem!
	
	
  // MARK: UIViewController Lifecycle
  
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Set up swipe to delete
		tableView.allowsMultipleSelectionDuringEditing = false

		configureStorage()
//		fetchConfig()
		logViewLoaded()
		
		// get snapshot of current user's friend data like name, id, etc. if available
		getMyFriendData()
		
		// might need to wait here, to prevent race condition if we don't get friend info in time
	
		setup()
	}
	
	func logViewLoaded() {
		FIRCrashMessage("View loaded")
	}
	
	deinit {
		self.masterRef.removeObserverWithHandle(_refHandle)
	}
	
	func configureStorage() {
		storageRef = FIRStorage.storage().referenceForURL("gs://project-kaerus.appspot.com")
	}
	
	
	// MARK:- Set up tableview, deadlines
	
	// set up the whole view
	func setup() {
		// this will be the ref all other refs base themselves upon
		masterRef = FIRDatabase.database().reference().child("User-Goals/\(userWhoseDeadlinesAreShown)")

		// get the day the user was last on
		let dayUserWasViewing = AppState.sharedInstance.userID! + "_viewing"
		dayUserLastSawRef = masterRef.child(dayUserWasViewing)
		dayUserLastSawRef.observeEventType(.Value, withBlock: { snapshot in
			if let day = snapshot.value as? Int {
				self.dayUserIsLookingAt = day
			}
			
			// disable back button if day == 1
			if self.dayUserIsLookingAt == 1 {
				self.backwardOneDay.enabled = false
			}
			
			// get the deadlines for the day user was last on
			self.deadlinesRef = self.masterRef.child("Goals/\(self.dayUserIsLookingAt)")
			self.getDeadlinesForDay()
		})
	}
	
	// load table with deadlines for the day user is looking at
	func getDeadlinesForDay() {
		// return a reference that queries by the "timeDue" property
		_refHandle = self.deadlinesRef.queryOrderedByChild("timeDue").observeEventType(.Value, withBlock: { snapshot in
			var newItems = [Goal]()
			let dayFormatter = NSDateFormatter()
			dayFormatter.dateStyle = .ShortStyle

			for item in snapshot.children {
				let goalItem = Goal(snapshot: item as! FIRDataSnapshot)
				newItems.append(goalItem)
			}
			self.items = newItems
			self.tableView.reloadData()
		})
	}
	
	
	// MARK:- Navigation bar elements
	
	@IBAction func didChangeSegmentControl(sender: AnyObject) {
		if segmentedControl.selectedSegmentIndex == 0 {
			// User looking at their own deadlines
			addDeadlineButton.enabled = true
			userWhoseDeadlinesAreShown = AppState.sharedInstance.userID!
		} else {
			// User looking at friend's deadlines
			addDeadlineButton.enabled = false
			userWhoseDeadlinesAreShown = AppState.sharedInstance.f_FIRid!
		}
		setup()
	}
	
	@IBAction func didPressBackward(sender: AnyObject) {
		dayUserIsLookingAt -= 1
		if dayUserIsLookingAt == 1 {
			backwardOneDay.enabled = false
		}
		dayUserLastSawRef.setValue(dayUserIsLookingAt)
		getDeadlinesForDay()
	}
	
	@IBAction func didPressForward(sender: AnyObject) {
		dayUserIsLookingAt += 1
		if dayUserIsLookingAt > 1 {
			backwardOneDay.enabled = true
		}
		dayUserLastSawRef.setValue(dayUserIsLookingAt)
		getDeadlinesForDay()
	}
	
	
	// MARK: UITableView Delegate methods

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return items.count
	}

	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		// user is only allowed to edit their own deadlines
		return segmentedControl.selectedSegmentIndex == 0 ? true : false
	}
	
	// change header height
	override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 40.0
	}
	
	override func tableView( tableView : UITableView,  titleForHeaderInSection section: Int) -> String {
		let day = "DAY " + String(dayUserIsLookingAt)
		return day
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cellIdentifier = "GoalsTableViewCell"
		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! GoalsTableViewCell
		return configureCell(cell, indexPath: indexPath)
	}
	
	func configureCell(cell: GoalsTableViewCell, indexPath: NSIndexPath) -> UITableViewCell {
		let goalItem = items[indexPath.row]
		cell.goalText.text = goalItem.text
		
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
		let timeDue = formatter.dateFromString(goalItem.timeDue!)
		formatter.dateFormat = "M/dd – h:mm a"
		let timeDueText = formatter.stringFromDate(timeDue!)
		
		cell.timeDueText.text = timeDueText
		
		// Determine whether the cell is checked
		toggleCellCheckbox(cell, isCompleted: goalItem.complete)
		
		// check if deadlines is past due (i.e. missed)
		if !goalItem.complete && timeDue!.timeIntervalSinceNow < 0 {
			cell.timeDueText.textColor = UIColor.redColor()
		}
		
		return cell
	}

	func toggleCellCheckbox(cell: UITableViewCell, isCompleted: Bool) {
		if !isCompleted {
			cell.accessoryType = UITableViewCellAccessoryType.None
			cell.textLabel?.textColor = UIColor.blackColor()
			cell.detailTextLabel?.textColor = UIColor.blackColor()
		} else {
			cell.accessoryType = UITableViewCellAccessoryType.Checkmark
			cell.textLabel?.textColor = UIColor.grayColor()
			cell.detailTextLabel?.textColor = UIColor.grayColor()
		}
	}
	
	// MARK: Navigation
	
	// called when starting to change from one screen in storyboard to next
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!)
	{
		if segue.identifier == "editItem" {
			// Edit item
			let goalsViewController = segue.destinationViewController as! MyGoalsAddItemViewController
			
			if let selectedItemCell = sender as? GoalsTableViewCell {
				let indexPath = tableView.indexPathForCell(selectedItemCell)!
				let selectedGoal = items[indexPath.row]
				goalsViewController.goal = selectedGoal
			}
		}
	}
	
	// saving when adding a new item or finished editing an old one
	@IBAction func unwindToGoalsList(sender: UIStoryboardSegue) {
		if let sourceViewController = sender.sourceViewController as? MyGoalsAddItemViewController, goal = sourceViewController.goal {
			var goalRef: FIRDatabaseReference
			if let selectedIndexPath = tableView.indexPathForSelectedRow {
				let key = items[selectedIndexPath.row].key
				// Update current item
				goalRef = self.deadlinesRef.child(key)
			}
			else {
				// Add a new item to the list
				goalRef = self.deadlinesRef.childByAutoId()
			}
			goalRef.setValue(goal.toAnyObject())
		}
	}
	
	// MARK:- get user's friend data, like name, pic, etc. 
	// TODO: make sure this guy really is your friend and isn't just some other guy who's friend status is set to FRIEND
	func getMyFriendData() {
		let getIdRef = FIRDatabase.database().reference().child("User-Friend-Info/\(AppState.sharedInstance.userID!)")
		getIdRef.observeEventType(FIRDataEventType.Value, withBlock: { (snapshot) in
			if let postDict = snapshot.value as? [String : AnyObject] {
				let friend_status: String = postDict["friend_status"] as! String
				
				if friend_status == "FRIEND" {
					AppState.sharedInstance.friend_status = friend_status
					
					if let friend_id: String = postDict["friend_id"] as? String {
						AppState.sharedInstance.f_FIRid = friend_id
					}
					
					if let friend_pic_url = postDict["friend_pic_url"] as? NSURL {
						print(friend_pic_url)
						AppState.sharedInstance.f_photoURL = friend_pic_url
					}
					
					if let friend_name = postDict["friend_name"] as? String {
						AppState.sharedInstance.f_displayName = friend_name
						
						let fullNameArr = friend_name.componentsSeparatedByString(" ")
						self.segmentedControl.setTitle(fullNameArr[0], forSegmentAtIndex: 1)
					}
					
					if let groupchat_id: String = postDict["groupchat_id"] as? String {
						AppState.sharedInstance.groupchat_id = groupchat_id
					}
				}
			}
		})
	}
	
	// swiping horizontally shows "done" button. pressing it will mark item as completed
	override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		
		//Get the cell
		let cell = tableView.cellForRowAtIndexPath(indexPath)!
		
		// Get the associated grocery item
		let goalItem = self.items[indexPath.row]
		
		let delete_button = UITableViewRowAction(style: .Destructive, title: "delete") { (action, indexPath) in
			let alert = UIAlertController(title: "Delete Deadline", message: "Are you sure you want to delete this deadline?", preferredStyle: .ActionSheet)
			let DeleteAction = UIAlertAction(title: "Delete", style: .Destructive, handler: { (action: UIAlertAction!) in
				goalItem.ref?.removeValue()
			})
			let CancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
			
			alert.addAction(DeleteAction)
			alert.addAction(CancelAction)
			
			// Support display in iPad
			alert.popoverPresentationController?.sourceView = self.view
			alert.popoverPresentationController?.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0)
			
			self.presentViewController(alert, animated: true, completion: nil)
		}
		
		// Get the new completion status
		let toggledCompletion = !goalItem.complete
		
		let done_button = UITableViewRowAction(style: .Normal, title: "complete") { (action, indexPath) in
			// Determine whether the cell is checked and modify it's view properties
			self.toggleCellCheckbox(cell, isCompleted: toggledCompletion)

			// Call updateChildValues on the grocery item's reference with just the new completed status
			goalItem.ref?.updateChildValues([
			  "complete": toggledCompletion ])
		}
		
		let blue = UIColor(red: 63/255, green: 202/255, blue: 62/255, alpha: 1)
		let green = UIColor(red: 66/255, green: 155/255, blue: 224/255, alpha: 1)
		
		done_button.title = toggledCompletion ? "mark as\ncomplete" : "mark as\nincomplete"
		done_button.backgroundColor = toggledCompletion ? blue : green
		
		return [delete_button, done_button]
	}
}
