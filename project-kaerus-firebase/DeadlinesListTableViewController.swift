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

class DeadlinesTableViewController: UITableViewController {
  // MARK: Constants
	let ListToUsers = "ListToUsers"
	
	
  // MARK: Properties
	var items = [Deadline]()
	var masterRef, deadlinesRef, dayUserLastSawRef: FIRDatabaseReference!
	private var _refHandle: FIRDatabaseHandle!
	var dayUserIsLookingAt = 1 // defaults to 1, but is set by the 'day' variable in User-Deadlines
	var userWhoseDeadlinesAreShown = AppState.sharedInstance.userID
	
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
		setFriendData()
		
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
		masterRef = FIRDatabase.database().reference().child("User-Deadlines/\(userWhoseDeadlinesAreShown)")

		// get the day the user was last on
		let dayUserWasViewing = AppState.sharedInstance.userID + "_viewing"
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
			self.deadlinesRef = self.masterRef.child("Deadlines/\(self.dayUserIsLookingAt)")
			self.getDeadlinesForDay()
		})
	}
	
	// load table with deadlines for the day user is looking at
	func getDeadlinesForDay() {
		// return a reference that queries by the "timeDue" property
		_refHandle = self.deadlinesRef.queryOrderedByChild("timeDue").observeEventType(.Value, withBlock: { snapshot in
			var newItems = [Deadline]()
			let dayFormatter = NSDateFormatter()
			dayFormatter.dateStyle = .ShortStyle

			for item in snapshot.children {
				let deadlineItem = Deadline(snapshot: item as! FIRDataSnapshot)
				newItems.append(deadlineItem)
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
			userWhoseDeadlinesAreShown = AppState.sharedInstance.userID
		} else {
			// User looking at friend's deadlines
			addDeadlineButton.enabled = false
			if let f_id = AppState.sharedInstance.f_firID {
				userWhoseDeadlinesAreShown = f_id
			} else {
				return
			}
		}
		setup()
	}
	
	@IBAction func didPressBackward(sender: AnyObject) {
		dayUserIsLookingAt -= 1
		if dayUserIsLookingAt == 1 {
			backwardOneDay.enabled = false
		}
		dayUserLastSawRef.setValue(dayUserIsLookingAt)
//		dayUserLastSawRef.removeAllObservers()
//		print("didPressBackward")
		getDeadlinesForDay()
	}
	
	@IBAction func didPressForward(sender: AnyObject) {
		dayUserIsLookingAt += 1
		if dayUserIsLookingAt > 1 {
			backwardOneDay.enabled = true
		}
		dayUserLastSawRef.setValue(dayUserIsLookingAt)
//		dayUserLastSawRef.removeAllObservers()
//		print("didPressForward")
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
	
	// header title
	override func tableView( tableView : UITableView,  titleForHeaderInSection section: Int) -> String {
		let day = "DAY " + String(dayUserIsLookingAt)
		return day
	}
	
	override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return UITableViewAutomaticDimension
	}
	
	override func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return UITableViewAutomaticDimension
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cellIdentifier = "DeadlinesTableViewCell"
		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! DeadlinesTableViewCell
		return configureCell(cell, indexPath: indexPath)
	}
	
	func configureCell(cell: DeadlinesTableViewCell, indexPath: NSIndexPath) -> UITableViewCell {
		let deadlineItem = items[indexPath.row]
		cell.deadlineText.text = deadlineItem.text
		
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
		let timeDue = formatter.dateFromString(deadlineItem.timeDue!)
		formatter.dateFormat = "M/dd – h:mm a"
		let timeDueText = formatter.stringFromDate(timeDue!)
		
		cell.timeDueText.text = timeDueText
		
		// Determine whether the cell is checked
		toggleCellCheckbox(cell, isCompleted: deadlineItem.complete)
		
		// check if deadlines is past due (i.e. missed)
		if !deadlineItem.complete && timeDue!.timeIntervalSinceNow < 0 {
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
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
		if segue.identifier == "editItem" {
			// Edit item
			let deadlinesViewController = segue.destinationViewController as! AddDeadlineViewController
			
			if let selectedItemCell = sender as? DeadlinesTableViewCell {
				let indexPath = tableView.indexPathForCell(selectedItemCell)!
				let selectedDeadline = items[indexPath.row]
				deadlinesViewController.deadline = selectedDeadline
			}
		}
	}
	
	// saving when adding a new item or finished editing an old one
	@IBAction func unwindToDeadlinesList(sender: UIStoryboardSegue) {
		if let sourceViewController = sender.sourceViewController as? AddDeadlineViewController, deadline = sourceViewController.deadline {
			var deadlineRef: FIRDatabaseReference
			if let selectedIndexPath = tableView.indexPathForSelectedRow {
				let key = items[selectedIndexPath.row].key
				// Update current item
				deadlineRef = self.deadlinesRef.child(key)
			}
			else {
				// Add a new item to the list
				deadlineRef = self.deadlinesRef.childByAutoId()
			}
			deadlineRef.setValue(deadline.toAnyObject())
		}
	}
	
	// MARK:- get user's friend data, like name, pic, etc. 
	func setFriendData() {
		if let status = AppState.sharedInstance.partnerStatus where status == true {
			let getIdRef = FIRDatabase.database().reference().child("Friend-Info/\(AppState.sharedInstance.userID)")
			getIdRef.observeEventType(FIRDataEventType.Value, withBlock: { (snapshot) in
				if let postDict = snapshot.value as? [String : String] {
					// set AppState stuff
					AppState.sharedInstance.f_firstName = postDict["friend_firstName"]
					self.segmentedControl.setTitle(AppState.sharedInstance.f_firstName, forSegmentAtIndex: 1)
					AppState.sharedInstance.f_firID = postDict["friend_id"]
					AppState.sharedInstance.f_photoURL = NSURL(string: postDict["friend_pic"]!)
					AppState.sharedInstance.f_name = postDict["friend_name"]
					AppState.sharedInstance.groupchat_id = postDict["groupchat_id"]
				}
			})
		}
	}
	
	// swiping horizontally shows "done" button. pressing it will mark item as completed
	override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		
		// Get the cell
		let cell = tableView.cellForRowAtIndexPath(indexPath)!
		
		// Get the associated grocery item
		let deadlineItem = self.items[indexPath.row]
		
		let delete_button = UITableViewRowAction(style: .Destructive, title: "delete") { (action, indexPath) in
			let alert = UIAlertController(title: "Delete Deadline", message: "Are you sure you want to delete this deadline?", preferredStyle: .ActionSheet)
			let DeleteAction = UIAlertAction(title: "Delete", style: .Destructive, handler: { (action: UIAlertAction!) in
				deadlineItem.ref?.removeValue()
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
		let toggledCompletion = !deadlineItem.complete
		
		let done_button = UITableViewRowAction(style: .Normal, title: "complete") { (action, indexPath) in
			// Determine whether the cell is checked and modify it's view properties
			self.toggleCellCheckbox(cell, isCompleted: toggledCompletion)

			// Call updateChildValues on the grocery item's reference with just the new completed status
			deadlineItem.ref?.updateChildValues([
			  "complete": toggledCompletion ])
		}
		
		let blue = UIColor(red: 63/255, green: 202/255, blue: 62/255, alpha: 1)
		let green = UIColor(red: 66/255, green: 155/255, blue: 224/255, alpha: 1)
		
		done_button.title = toggledCompletion ? "mark as\ncomplete" : "mark as\nincomplete"
		done_button.backgroundColor = toggledCompletion ? blue : green
		
		return [delete_button, done_button]
	}
}
