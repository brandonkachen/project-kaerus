//
//  CalendarViewController.swift
//  
//
//  Created by Brandon Chen on 8/7/16.
//
//

import JTAppleCalendar
import Firebase

class DeadlinesViewController: UIViewController {
	// calendar view stuff
	@IBOutlet weak var calendarView: JTAppleCalendarView!
	@IBOutlet weak var fullCalendarView: UIView!
	@IBOutlet weak var monthLabel: UILabel!
	let calendar: NSCalendar! = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
	let formatter = NSDateFormatter()
	
	// deadline table stuff
	@IBOutlet weak var segControl: UISegmentedControl!
	@IBOutlet weak var addButton: UIBarButtonItem!
	@IBOutlet weak var userDeadlineTable: UITableView!
	@IBOutlet weak var userOwesLabel: UILabel!
	@IBOutlet weak var partnerDeadlineTable: UITableView!
	@IBOutlet weak var partnerOwesLabel: UILabel!

	var deadlines = [Deadline]()
	var masterRef, deadlinesRef, dayUserLastSawRef, amtOwedEachDayRef: FIRDatabaseReference!
	private var _refHandle: FIRDatabaseHandle!
	var dayUserIsLookingAt: String! // set by the 'day' variable in User-Deadlines
	
	var storageRef: FIRStorageReference!

	override func viewDidLoad() {
		super.viewDidLoad()
		// Set up swipe to delete
		userDeadlineTable.allowsMultipleSelectionDuringEditing = false
		partnerDeadlineTable.allowsMultipleSelectionDuringEditing = false
		
		configureStorage()
//		fetchConfig()
		logViewLoaded()
		
		// get today's deadlines on initial load
		self.formatter.dateFormat = "yyyy-MM-dd Z"
		self.dayUserIsLookingAt = formatter.stringFromDate(NSDate())
		
		AppState.sharedInstance.f_firstName != nil ?
			self.segControl.setTitle(AppState.sharedInstance.f_firstName, forSegmentAtIndex: 1) :
			segControl.setEnabled(false, forSegmentAtIndex: 1)
		
		// might need to wait here, to prevent race condition if we don't get friend info in time
		setup(AppState.sharedInstance.userID)
		setup(AppState.sharedInstance.f_firID!)
		
		self.calendarView.dataSource = self
		self.calendarView.delegate = self
		self.calendarView.registerCellViewXib(fileName: "CellView")
		self.calendarView.selectDates([NSDate()])
		self.calendarView.scrollToDate(NSDate())
		self.calendarView.cellInset = CGPoint(x: 0, y: 0)
		
		self.fullCalendarView.layer.addBorder(.Bottom, color: UIColor.whiteColor(), thickness: 1.0)
		self.fullCalendarView.layer.shadowOffset = CGSizeMake(1, 1)
		self.fullCalendarView.layer.shadowColor = UIColor.lightGrayColor().CGColor
		self.fullCalendarView.layer.shadowOpacity = 0.5
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
	
	
	// MARK:- Set up deadlines
	// set up the whole view
	func setup(userID: String!) {
		// this will be the ref upon which all other refs base themselves
		masterRef = FIRDatabase.database().reference().child("User-Deadlines/\(userID)")
		self.getDeadlinesForDay()
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
		self.amtOwedEachDayRef = self.masterRef.child("Owed/\(self.dayUserIsLookingAt)")
		// return a reference that queries by the "timeDue" property
		_refHandle = self.deadlinesRef.queryOrderedByChild("timeDue").observeEventType(.Value, withBlock: { snapshot in
			var newItems = [Deadline]()
			for item in snapshot.children {
				let deadlineItem = Deadline(snapshot: item as! FIRDataSnapshot)
				newItems.append(deadlineItem)
			}
			self.deadlines = newItems
			self.userDeadlineTable.reloadData()
			completion(result: self.deadlines.count)
		})
	}
	
	// determine how much the user owes for this particular day
	func determineOwedBalance(totalCount: Int) {
		getMissedDeadlineCount() { (missedCount) -> () in
			self.userOwesLabel.text! = "owed: $"
			let strAmt: String
			if missedCount > 0 { // if deadline count <= 5, every missed deadline costs $(2.50/deadline count). otherwise, missed deadlines are charged at a flat rate of $0.50 each.
				var amt = Double(missedCount)
				amt *= totalCount >= 5 ? 0.5 : (2.5/Double(totalCount))
				amt = Double(round(100*amt)/100)
				strAmt = String(format: "%.2f", amt)
				self.amtOwedEachDayRef.setValue(strAmt)
			} else {
				strAmt = "0"
				self.amtOwedEachDayRef.removeValue()
			}
			self.userOwesLabel.text! += strAmt
		}
	}
	
	// get count of missed deadlines
	func getMissedDeadlineCount(completion: (result: Int)->()) {
		self.deadlinesRef.queryOrderedByChild("complete").queryEqualToValue(false).observeEventType(.Value, withBlock: { snapshot in
			var missedCount = 0
			for item in snapshot.children {
				let deadlineItem = Deadline(snapshot: item as! FIRDataSnapshot)
				let formatter = NSDateFormatter()
				formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
				let timeDue = formatter.dateFromString(deadlineItem.timeDue!)!
				
				if timeDue.timeIntervalSinceNow < 0 {
					missedCount += 1
				}
			}
			completion(result: missedCount)
		})
	}
	
	
	// MARK: calendar setup
	func setupViewsOfCalendar(startDate: NSDate, endDate: NSDate) {
		let month = calendar.component(NSCalendarUnit.Month, fromDate: startDate)
		let monthName = NSDateFormatter().monthSymbols[(month-1) % 12] // 0 indexed array
		let year = NSCalendar.currentCalendar().component(NSCalendarUnit.Year, fromDate: startDate)
		monthLabel.text = monthName + " " + String(year)
	}
	
	override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: JTAppleCalendar Delegate methods
extension DeadlinesViewController: JTAppleCalendarViewDataSource, JTAppleCalendarViewDelegate  {
	func configureCalendar(calendar: JTAppleCalendarView) -> (startDate: NSDate, endDate: NSDate, numberOfRows: Int, calendar: NSCalendar) {
		let firstDate = AppState.sharedInstance.startDate
		let components = NSDateComponents()
		components.month = 1
		let secondDate = NSCalendar.currentCalendar().dateByAddingComponents(components, toDate: NSDate(), options: NSCalendarOptions())!
		let numberOfRows = 1
		let aCalendar = NSCalendar.currentCalendar() // Properly configure your calendar to your time zone here
		
		return (startDate: firstDate, endDate: secondDate, numberOfRows: numberOfRows, calendar: aCalendar)
	}
	
	func calendar(calendar: JTAppleCalendarView, isAboutToDisplayCell cell: JTAppleDayCellView, date: NSDate, cellState: CellState) {
		(cell as! CellView).setupCellBeforeDisplay(cellState, date: date)
	}
	
	func calendar(calendar: JTAppleCalendarView, didSelectDate date: NSDate, cell: JTAppleDayCellView?, cellState: CellState) {
		let strDay = self.formatter.stringFromDate(date)
		self.dayUserIsLookingAt = strDay
		setup(AppState.sharedInstance.userID)
		setup(AppState.sharedInstance.f_firID!)
		(cell as? CellView)?.cellSelectionChanged(cellState)
	}
	
	func calendar(calendar: JTAppleCalendarView, didDeselectDate date: NSDate, cell: JTAppleDayCellView?, cellState: CellState) {
		(cell as? CellView)?.cellSelectionChanged(cellState)
	}
	
	func calendar(calendar: JTAppleCalendarView, didScrollToDateSegmentStartingWithdate startDate: NSDate, endingWithDate endDate: NSDate) {
		setupViewsOfCalendar(startDate, endDate: endDate)
	}
}

// MARK: UITableView Delegate methods
extension DeadlinesViewController {
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
		
		let cellTimeFormatter = NSDateFormatter()
		cellTimeFormatter.dateFormat = "yyyy-MM-dd HH:mmZ"
		let timeDue = cellTimeFormatter.dateFromString(deadlineItem.timeDue!)
		
		// configure the date to show
		cellTimeFormatter.dateFormat = "h:mm a"
		let timeDueText = cellTimeFormatter.stringFromDate(timeDue!)
		
		cell.timeDueText.text = timeDueText
		
		// Determine whether the cell is checked
		toggleCellCheckbox(cell, isCompleted: deadlineItem.complete)
		
		// check if deadlines is past due (i.e. missed)
		if !deadlineItem.complete && timeDue!.timeIntervalSinceNow < 0 {
			cell.timeDueText.textColor = UIColor.redColor()
		}
		
//		cell.layer.addBorder(.Bottom, color: UIColor.whiteColor(), thickness: 0.0)
//		cell.layer.shadowOffset = CGSizeMake(1, 1)
//		cell.layer.shadowColor = UIColor.lightGrayColor().CGColor
//		cell.layer.shadowOpacity = 0.5
		
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
}

// MARK: Navigation
extension DeadlinesViewController {
	override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
		return segControl.selectedSegmentIndex == 0 ? true : false
	}
	
//	@IBAction func didChangeSegment(sender: AnyObject) {
//		if segControl.selectedSegmentIndex == 0 { // user looking at their own deadlines
//			addButton.enabled = true
//			userWhoseDeadlinesAreShown = AppState.sharedInstance.userID
//		} else { // user looking at partner's deadlines
//			addButton.enabled = false
//			if let f_id = AppState.sharedInstance.f_firID {
//				userWhoseDeadlinesAreShown = f_id
//			} else {
//				return
//			}
//		}
//		setup()
//	}
	
	// called when starting to change from one screen in storyboard to next
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
		if segue.identifier == "editItem" { // Edit item
			let deadlinesViewController = segue.destinationViewController as! AddDeadlineViewController
			if let selectedItemCell = sender as? DeadlinesTableViewCell {
				let indexPath = userDeadlineTable.indexPathForCell(selectedItemCell)!
				let selectedDeadline = deadlines[indexPath.row]
				deadlinesViewController.deadline = selectedDeadline
			}
		}
	}
	
	// saving when adding a new item or finished editing an old one
	@IBAction func unwindToDeadlinesList(sender: UIStoryboardSegue) {
		if let sourceViewController = sender.sourceViewController as? AddDeadlineViewController, deadline = sourceViewController.deadline {
			var deadlineRef: FIRDatabaseReference
			if let selectedIndexPath = userDeadlineTable.indexPathForSelectedRow { // Update current item
				let key = deadlines[selectedIndexPath.row].key
				deadlineRef = self.deadlinesRef.child(key)
			} else { // Add a new item to the list
				deadlineRef = self.deadlinesRef.childByAutoId()
			}
			deadlineRef.setValue(deadline.toAnyObject())
		}
	}
}

func delayRunOnMainThread(delay:Double, closure:()->()) {
	dispatch_after(
		dispatch_time(
			DISPATCH_TIME_NOW,
			Int64(delay * Double(NSEC_PER_SEC))
		),
		dispatch_get_main_queue(), closure)
}