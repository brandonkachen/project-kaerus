//
//  DeadlinesViewController.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/5/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit
import Firebase

class DeadlinesViewController: UIViewController {
	@IBOutlet weak var segControl: UISegmentedControl!
	@IBOutlet weak var addButton: UIBarButtonItem!
	@IBOutlet weak var backOneDayButton: UIButton!
	@IBOutlet weak var forwardOneDayButton: UIButton!
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var amtOwedLabel: UILabel!
	@IBOutlet weak var deadlineTable: UITableView!
	
	
	// MARK: Properties

	var deadlines = [Deadline]()
	var masterRef, deadlinesRef, dayUserLastSawRef, dateRef: FIRDatabaseReference!
	private var _refHandle: FIRDatabaseHandle!
	var dayUserIsLookingAt = 1 // defaults to 1, but is set by the 'day' variable in User-Deadlines
	var userWhoseDeadlinesAreShown = AppState.sharedInstance.userID
	var dayStart: NSDate!
	var dayEnd: NSDate!
	
	var storageRef: FIRStorageReference!
	
	
	// MARK: UIViewController Lifecycle
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Set up swipe to delete
		deadlineTable.allowsMultipleSelectionDuringEditing = false
		
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
		setupDate()
		self.getDeadlinesForDay()
	}
	
	// set up all the date information
	func setupDate() {
		// get the day the user was last on
		let dayUserWasViewing = AppState.sharedInstance.userID + "_viewing"
		dayUserLastSawRef = masterRef.child(dayUserWasViewing)
		dayUserLastSawRef.observeEventType(.Value, withBlock: { snapshot in
			if let day = snapshot.value as? Int {
				self.dayUserIsLookingAt = day
			}
			
			// disable back button if day == 1
			if self.dayUserIsLookingAt == 1 {
				self.backOneDayButton.enabled = false
			}
			/*
			// get date data to show
			self.dateRef = self.masterRef.child("Dates/\(self.dayUserIsLookingAt)")
			self.dateRef.observeEventType(.Value, withBlock: { snapshot in
				if let postDict = snapshot.value as? [String : AnyObject] {
					let start = postDict["dayStart"] as! String
					let end = postDict["dayEnd"] as! String
					
					let formatter = NSDateFormatter()
					formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
					self.dayStart = formatter.dateFromString(start)
					self.dayEnd = formatter.dateFromString(end)
					formatter.dateFormat = "M/d"
					let components =
						NSCalendar.currentCalendar().components([.Day],
							fromDate: self.dayStart,
							toDate: self.dayEnd,
							options: [])
					self.dateLabel.text = components.day < 1
						? formatter.stringFromDate(self.dayStart) :
						formatter.stringFromDate(self.dayStart) + " – " + formatter.stringFromDate(self.dayEnd)
				} else { // date has not yet been created
					
//					let components =
//						NSCalendar.currentCalendar().components([.Day],
//							fromDate: self.dayEnd,
//							toDate: NSDate(),
//							options: [])
//					self.dateLabel.text = components.day < 1 ?  :
				}
			})*/
		})
	}
	
	// load table with deadlines for the day user is looking at
	func getDeadlinesForDay() {
		getDeadlines() { (result) -> () in
			self.determineOwedBalance(result)
		}
	}
	
	// get the deadlines
	func getDeadlines(completion: (result: Int)->()) {
		self.deadlinesRef = self.masterRef.child("Deadlines/\(self.dayUserIsLookingAt)")
		// return a reference that queries by the "timeDue" property
		_refHandle = self.deadlinesRef.queryOrderedByChild("timeDue").observeEventType(.Value, withBlock: { snapshot in
			var newItems = [Deadline]()
			let dayFormatter = NSDateFormatter()
			dayFormatter.dateStyle = .ShortStyle
			
			for item in snapshot.children {
				let deadlineItem = Deadline(snapshot: item as! FIRDataSnapshot)
				newItems.append(deadlineItem)
			}
			self.deadlines = newItems
			self.deadlineTable.reloadData()
			var start, end: String
			
			let formatter = NSDateFormatter()
			if !newItems.isEmpty {
				formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
				self.dayEnd = formatter.dateFromString(self.deadlines.last!.timeDue!)
				self.dayStart = formatter.dateFromString(self.deadlines.first!.timeDue!)
			} else { // new day
				let components = NSDateComponents()
				components.day = 1
				self.dayStart = NSCalendar.currentCalendar().dateByAddingComponents(components, toDate: self.dayStart, options: NSCalendarOptions())!
				self.dayEnd = NSCalendar.currentCalendar().dateByAddingComponents(components, toDate: self.dayEnd, options: NSCalendarOptions())!
			}
			formatter.dateFormat = "M/d"
			start = formatter.stringFromDate(self.dayStart)
			end = formatter.stringFromDate(self.dayEnd)
			self.dateLabel.text = start != end ? start + " – " + end : start

			completion(result: self.deadlines.count)
		})
	}
	
	// determine how much the user owes for this particular day
	func determineOwedBalance(totalCount: Int) {
		getMissedDeadlineCount() { (missedCount) -> () in
			self.amtOwedLabel.text! = "owed: $"
			if missedCount > 0 { // if deadline count <= 5, every missed deadline costs $(2.50/deadline count). otherwise, missed deadlines are charged at a flat rate of $0.50 each.
				var amt = Double(missedCount)
				amt *= totalCount >= 5 ? 0.5 : (2.5/Double(totalCount))
				amt = Double(round(100*amt)/100)
				self.amtOwedLabel.text! += String(format: "%.2f", amt)
			} else {
				self.amtOwedLabel.text! += "0"
			}
		}
	}
	
	// get count of missed deadlines
	func getMissedDeadlineCount(completion: (result: Int)->()) {
		self.deadlinesRef.queryOrderedByChild("complete").queryEqualToValue(false).observeEventType(.Value, withBlock: { snapshot in
			var missedCount = 0
			for item in snapshot.children {
				let formatter = NSDateFormatter()
				formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
				let deadlineItem = Deadline(snapshot: item as! FIRDataSnapshot)
				let timeDue = formatter.dateFromString(deadlineItem.timeDue!)!
				
				if timeDue.timeIntervalSinceNow < 0 {
					missedCount += 1
				}
			}
			completion(result: missedCount)
		})
	}
	
	
	// MARK:- Navigation bar elements
	
	@IBAction func didChangeSegment(sender: AnyObject) {
		if segControl.selectedSegmentIndex == 0 { // user looking at their own deadlines
			addButton.enabled = true
			userWhoseDeadlinesAreShown = AppState.sharedInstance.userID
		} else { // user looking at partner's deadlines
			addButton.enabled = false
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
			backOneDayButton.enabled = false
		}
		dayUserLastSawRef.setValue(dayUserIsLookingAt)
		getDeadlinesForDay()
	}
	
	@IBAction func didPressForward(sender: AnyObject) {
		dayUserIsLookingAt += 1
		if dayUserIsLookingAt > 1 {
			backOneDayButton.enabled = true
		}
		dayUserLastSawRef.setValue(dayUserIsLookingAt)
		getDeadlinesForDay()
	}
	
	
	// MARK: UITableView Delegate methods
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return deadlines.count
	}
	
	func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		// user is only allowed to mark "finished" or delete their own deadlines
		return segControl.selectedSegmentIndex == 0 ? true : false
	}
	
	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return UITableViewAutomaticDimension
	}
	
	func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return UITableViewAutomaticDimension
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cellIdentifier = "DeadlinesTableViewCell"
		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! DeadlinesTableViewCell
		return configureCell(cell, indexPath: indexPath)
	}
	
	func configureCell(cell: DeadlinesTableViewCell, indexPath: NSIndexPath) -> UITableViewCell {
		let deadlineItem = deadlines[indexPath.row]
		cell.deadlineText.text = deadlineItem.text
		
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
		let timeDue = formatter.dateFromString(deadlineItem.timeDue!)
		formatter.dateFormat = "h:mm a"
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
	
	// swiping horizontally shows "done" button. pressing it will mark item as completed
	func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		// Get the cell
		let cell = tableView.cellForRowAtIndexPath(indexPath)!
		
		// Get the associated grocery item
		let deadlineItem = self.deadlines[indexPath.row]
		
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
			
			// Call updateChildValues on the deadline's reference with just the new completed status
			deadlineItem.ref?.updateChildValues([
				"complete": toggledCompletion ])
		}
		
		let blue = UIColor(red: 63/255, green: 202/255, blue: 62/255, alpha: 1)
		let green = UIColor(red: 66/255, green: 155/255, blue: 224/255, alpha: 1)
		
		done_button.title = toggledCompletion ? "finish" : "un-finish"
		done_button.backgroundColor = toggledCompletion ? blue : green
		
		return [delete_button, done_button]
	}

	
	// MARK: Navigation
	
	override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
		return segControl.selectedSegmentIndex == 0 ? true : false
	}
	
	// called when starting to change from one screen in storyboard to next
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
		if segue.identifier == "editItem" { // Edit item
			let deadlinesViewController = segue.destinationViewController as! AddDeadlineViewController
			if let selectedItemCell = sender as? DeadlinesTableViewCell {
				let indexPath = deadlineTable.indexPathForCell(selectedItemCell)!
				let selectedDeadline = deadlines[indexPath.row]
				deadlinesViewController.deadline = selectedDeadline
			}
		}
	}
	
	// saving when adding a new item or finished editing an old one
	@IBAction func unwindToDeadlinesList(sender: UIStoryboardSegue) {
		if let sourceViewController = sender.sourceViewController as? AddDeadlineViewController, deadline = sourceViewController.deadline {
			var deadlineRef: FIRDatabaseReference
			if let selectedIndexPath = deadlineTable.indexPathForSelectedRow { // Update current item
				let key = deadlines[selectedIndexPath.row].key
				deadlineRef = self.deadlinesRef.child(key)
			} else { // Add a new item to the list
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
				if let postDict = snapshot.value as? [String : String] { // set AppState stuff
					AppState.sharedInstance.f_firstName = postDict["friend_firstName"]
					self.segControl.setTitle(AppState.sharedInstance.f_firstName, forSegmentAtIndex: 1)
					AppState.sharedInstance.f_firID = postDict["friend_id"]
					AppState.sharedInstance.f_photoURL = NSURL(string: postDict["friend_pic"]!)
					AppState.sharedInstance.f_photo = UIImage(data: NSData(contentsOfURL: AppState.sharedInstance.f_photoURL!)!)!.circle
					AppState.sharedInstance.f_name = postDict["friend_name"]
					AppState.sharedInstance.groupchat_id = postDict["groupchat_id"]
				}
			})
		} else { // user doesn't have a friend, so gray out 'partner' segment
			segControl.setEnabled(false, forSegmentAtIndex: 1)
		}
	}
}
