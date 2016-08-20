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
	@IBOutlet weak var deadlineTable: UITableView!
	@IBOutlet weak var editButton: UIBarButtonItem!
	@IBOutlet weak var paymentCard: UIView!
	@IBOutlet weak var blurView: UIView!
	@IBOutlet weak var paymentCardLabel: UILabel!
	@IBOutlet weak var amtOwedLabel: UILabel!
	@IBOutlet weak var amtOwedView: UIView!
	
	var deadlines = [Deadline]()
	var masterRef, deadlinesRef, dayUserLastSawRef, amtOwedEachDayRef, lastDatePaid: FIRDatabaseReference!
	private var _refHandle: FIRDatabaseHandle!
	var userWhoseDeadlinesAreShown = AppState.sharedInstance.userID
	var dayUserIsLookingAt: String! // set by the 'day' variable in User-Deadlines
	var lastDateUserPaid: NSDate!
	
	var storageRef: FIRStorageReference!

	override func viewDidLoad() {
		super.viewDidLoad()
		
		configureStorage()
//		fetchConfig()
		logViewLoaded()
		
		// get today's deadlines on initial load
		formatter.dateFormat = "yyyy-MM-dd Z"
		dayUserIsLookingAt = formatter.stringFromDate(NSDate())
		
		AppState.sharedInstance.f_firstName != nil ?
			segControl.setTitle(AppState.sharedInstance.f_firstName, forSegmentAtIndex: 1) :
			segControl.setEnabled(false, forSegmentAtIndex: 1)
		
		calendarView.dataSource = self
		calendarView.delegate = self
		calendarView.registerCellViewXib(fileName: "CellView")
		calendarView.selectDates([NSDate()])
		calendarView.scrollToDate(NSDate())

		fullCalendarView.layer.shadowOffset = CGSizeMake(1, 1)
		fullCalendarView.layer.shadowColor = UIColor.lightGrayColor().CGColor
		fullCalendarView.layer.shadowOpacity = 0.5
		
		paymentCard.layer.shadowOffset = CGSizeMake(1, 1)
		paymentCard.layer.shadowColor = UIColor.lightGrayColor().CGColor
		paymentCard.layer.shadowOpacity = 0.3
		
		amtOwedView.layer.shadowOffset = CGSizeMake(1, 1)
		amtOwedView.layer.shadowColor = UIColor.lightGrayColor().CGColor
		amtOwedView.layer.shadowOpacity = 0.5
		
		blurView.backgroundColor = UIColor.blackColor()
		blurView.alpha = 0.8
		
//		self.navigationController!.navigationBar.setBackgroundImage(imageLayerForGradientBackground(), forBarMetrics: .Default)
		
		// blur version
//		let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.Dark)
//		let blurEffectView = UIVisualEffectView(effect: blurEffect)
//		blurEffectView.alpha = 0.7
//		blurEffectView.frame = blurView.bounds
//		blurView.addSubview(blurEffectView)
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
	
	private func imageLayerForGradientBackground() -> UIImage {
		var updatedFrame = self.navigationController!.navigationBar.bounds
		// take into account the status bar
		updatedFrame.size.height += 20
		let layer = CAGradientLayer.gradientLayerForBounds(updatedFrame)
		UIGraphicsBeginImageContext(layer.bounds.size)
		layer.renderInContext(UIGraphicsGetCurrentContext()!)
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image
	}
	
	// MARK:- Set up deadlines
	// set up the whole view
	func setup() {
		// this will be the ref upon which all other refs base themselves
		masterRef = FIRDatabase.database().reference().child("User-Deadlines/\(userWhoseDeadlinesAreShown)")
		self.deadlinesRef = self.masterRef.child("Deadlines/\(self.dayUserIsLookingAt)")
		self.amtOwedEachDayRef = self.masterRef.child("Owed/\(self.dayUserIsLookingAt)")
		lastDatePaid = masterRef.child("Last-Date-Paid")
		self.getDeadlinesForDay()
		self.checkIfUserNeedsToPay()
	}
	
	// TODO: change to static variables for performance
	func checkIfUserNeedsToPay() {
		// check only if user is looking at next day
		let todayDate = formatter.stringFromDate(NSDate()) // just get the date portion of today
		if dayUserIsLookingAt < todayDate { // if user is looking at any date before today
			self.blurView.hidden = true
			self.paymentCard.hidden = true
			self.editButton.enabled = true
			return
		}
		
		lastDatePaid.observeEventType(.Value, withBlock: { snapshot in
			if let str_ld = snapshot.value as? String {
				let calendar = NSCalendar.currentCalendar()
				// convert str_ld to NSDate format
				let dateFormatter = NSDateFormatter()
				dateFormatter.dateFormat = "yyyy-MM-dd Z"
				self.lastDateUserPaid = dateFormatter.dateFromString(str_ld)!
				let nextDay = calendar.dateByAddingUnit(.Day, value: 1, toDate: self.lastDateUserPaid, options: [])
				
				// convert next date back to string
				let str_nd = dateFormatter.stringFromDate(nextDay!)
				
				// compare the last date user paid to owed deadlines
				self.masterRef.child("Owed").queryOrderedByKey().queryStartingAtValue(str_nd).observeSingleEventOfType(.Value, withBlock: { snapshot in
					if let items = snapshot.value as? [String : String] {
						var total: Double = 0
						for item in items { total += Double(item.1)! }
						self.paymentCardLabel.text = "You owe $\(String(format: "%.2f", total)).\nYou can't access this day until you pay your partner."
						self.blurView.hidden = false
						self.paymentCard.hidden = false
						self.editButton.enabled = false
					} else {
						self.blurView.hidden = true
						self.paymentCard.hidden = true
						self.editButton.enabled = true
					}
				})
			}
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
		// return a reference that queries by the "timeDue" property
		_refHandle = self.deadlinesRef.queryOrderedByChild("timeDue").observeEventType(.Value, withBlock: { snapshot in
			var newItems = [Deadline]()
			for item in snapshot.children {
				let deadlineItem = Deadline(snapshot: item as! FIRDataSnapshot)
				newItems.append(deadlineItem)
			}
			
			self.editButton.title = newItems.isEmpty ? "New" : "Edit"

			self.deadlines = newItems
			self.deadlineTable.reloadData()
			completion(result: self.deadlines.count)
		})
	}
	
	// determine how much the user owes for this particular day
	func determineOwedBalance(totalCount: Int) {
		getMissedDeadlineCount() { (missedCount) -> () in
			let strAmt: String
			if missedCount > 0 { // if deadline count <= 5, every missed deadline costs $(2.50/deadline count). otherwise, missed deadlines are charged at a flat rate of $0.50 each.
				var amt = Double(missedCount)
				amt *= totalCount >= 5 ? 0.5 : (2.5/Double(totalCount))
				amt = Double(round(100*amt)/100)
				strAmt = String(format: "%.2f", amt)
				self.amtOwedEachDayRef.setValue(strAmt)
				self.amtOwedLabel.text! = "owed: $\(strAmt)"
			} else {
				self.amtOwedEachDayRef.removeValue()
				self.amtOwedLabel.text = "nothing owed!"
			}
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
		let secondDate = NSDate()
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
		setup()
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
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		// get cell, its ref, and its status
		let cell = tableView.cellForRowAtIndexPath(indexPath)!
		let deadlineItem = self.deadlines[indexPath.row]
		let toggledCompletion = !deadlineItem.complete
		
		// update item
		self.toggleCellCheckbox(cell, isCompleted: toggledCompletion)
		deadlineItem.ref?.updateChildValues([
			"complete": toggledCompletion ])
	}
}

// MARK: Navigation
extension DeadlinesViewController {
	override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
		return segControl.selectedSegmentIndex == 0 ? true : false
	}
	
	@IBAction func didChangeSegment(sender: AnyObject) {
		if segControl.selectedSegmentIndex == 0 { // user looking at their own deadlines
			userWhoseDeadlinesAreShown = AppState.sharedInstance.userID
			// show edit button
			self.editButton.tintColor = self.navigationController?.navigationBar.tintColor
			self.editButton.enabled = true
		} else { // user looking at partner's deadlines
			userWhoseDeadlinesAreShown = AppState.sharedInstance.f_firID!
			// jank way of hiding edit button
			self.editButton.tintColor = UIColor.clearColor()
			self.editButton.enabled = false
		}
		setup()
	}
	
	// called when starting to change from one screen in storyboard to next
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
		let navController = segue.destinationViewController as! UINavigationController
		let deadlinesViewController = navController.topViewController as! EditDeadlinesViewController
		deadlinesViewController.deadlines = deadlines
		deadlinesViewController.date = dayUserIsLookingAt
	}
	
	// saving when adding a new item or finished editing an old one
	@IBAction func unwindToDeadlinesList(sender: UIStoryboardSegue) {
		if let sourceViewController = sender.sourceViewController as? EditDeadlinesViewController {
			// set Firebase to updated items
			deadlinesRef.removeValue()
			for deadline in sourceViewController.deadlines {
				deadlinesRef.childByAutoId().setValue(deadline.toAnyObject())
			}
			
			if let chatId = AppState.sharedInstance.groupchat_id {
				let messageRef = FIRDatabase.database().reference().child("Messages/\(chatId)")
				
				// get timestamp for new message
				let dateFormatter = NSDateFormatter()
				dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SS"
				dateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
				
				// add sender's ID so if users send messages at the exact same time (however unlikely), they won't erase one another
				let timestamp = dateFormatter.stringFromDate(NSDate()) + "<" + AppState.sharedInstance.userID + ">"
				
				let status = sourceViewController.deadlines.count == 0 ? "set" : "edited"
				let message = status + " my schedule for \(sourceViewController.dateLabel.text!)"
				
				// create the new entry
				let messageItem = [
					"id" : AppState.sharedInstance.userID,
					"displayName" : AppState.sharedInstance.firstName,
					"text" : message + " – " + sourceViewController.explanation // TODO: remove - when status == "set"
				]
				messageRef.child(timestamp).setValue(messageItem)
				
				// send a notification to partner
				OneSignal.postNotification([
					"contents": ["en": AppState.sharedInstance.firstName + ": " + message],
					"include_player_ids": [AppState.sharedInstance.f_oneSignalID!],
					"content_available": ["true"]
					])
			}
		}
	}
	
	// TODO
	@IBAction func didPressPayButton(sender: AnyObject) {
		
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