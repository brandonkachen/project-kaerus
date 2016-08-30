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
	let dateFormatter = NSDateFormatter()
	let detailedDateFormatter = NSDateFormatter()
	
	// deadline table stuff
	@IBOutlet weak var segControl: UISegmentedControl!
	@IBOutlet weak var deadlineTable: UITableView!
	@IBOutlet weak var editButton: UIBarButtonItem!
	@IBOutlet weak var paymentCard: UIView!
	@IBOutlet weak var blurView: UIView!
	@IBOutlet weak var paymentCardLabel: UILabel!
	@IBOutlet weak var amtOwedLabel: UILabel!
	@IBOutlet weak var amtOwedView: UIView!
	@IBOutlet weak var payButton: UIBarButtonItem!
	
	var userDeadlines = [Deadline]()
	var partnerDeadlines = [Deadline]()
	var ref, userRef, userDeadlinesRef, partnerRef, partnerDeadlineRef, owesRef, dayUserLastSawRef, lastDatePaidRef: FIRDatabaseReference!
	private var _userDeadlinesRefHandle, _partnerDeadlinesRefHandle: FIRDatabaseHandle!
	var dayUserIsLookingAt: String! // set by the 'day' variable in User-Deadlines
	var userTotal: Double = 0
	var partnerTotal: Double = 0
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// set up refs that don't rely on dayUserIsLookingAt for user
		ref = FIRDatabase.database().reference()
		setPartnerStuff()

//		fetchConfig()
		logViewLoaded()
		
		// get today's deadlines on initial load
		dateFormatter.dateFormat = "yyyy-MM-dd Z"
		dayUserIsLookingAt = dateFormatter.stringFromDate(NSDate())
		
		// used for timestamps or where time precision is needed
		detailedDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SS"
		detailedDateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
		
		calendarView.dataSource = self
		calendarView.delegate = self
		calendarView.registerCellViewXib(fileName: "CellView")
		calendarView.selectDates([NSDate()])
		calendarView.scrollToDate(NSDate())
		
		amtOwedView.layer.shadowOffset = CGSizeMake(1, 1)
		amtOwedView.layer.shadowColor = UIColor.lightGrayColor().CGColor
		amtOwedView.layer.shadowOpacity = 0.5
		
		paymentCard.layer.shadowOffset = CGSizeMake(1, 1)
		paymentCard.layer.shadowColor = UIColor.lightGrayColor().CGColor
		paymentCard.layer.shadowOpacity = 0.5
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.partnerStatusChanged(_:)), name: "PartnerInfoChanged_Deadlines", object: nil)
		
//		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.partnerStatusChanged(_:)), name: "lastPaidDateChanged", object: nil)
	}
	
	deinit {
		self.userDeadlinesRef.removeObserverWithHandle(_userDeadlinesRefHandle)
		if partnerDeadlineRef != nil {
			self.partnerDeadlineRef.removeObserverWithHandle(_partnerDeadlinesRefHandle)
		}
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	func partnerStatusChanged(_: NSNotification) {
		setPartnerStuff()
	}
	
	func logViewLoaded() {
		FIRCrashMessage("View loaded")
	}
	
	// MARK: Set up partner's deadline stuff
	
	func setPartnerStuff() {
		if AppState.sharedInstance.f_firstName == nil {	// no partner, so disable partner button in segControl and remove observer if possible
			segControl.setTitle("Partner", forSegmentAtIndex: 1)
			segControl.setEnabled(false, forSegmentAtIndex: 1)
			segControl.selectedSegmentIndex = 0
			if partnerDeadlineRef != nil {
				self.partnerDeadlineRef.removeObserverWithHandle(_partnerDeadlinesRefHandle)
			}
			partnerDeadlineRef = nil
			partnerRef = nil
		} else { // user has partner - load their data separately from user's
			// set segControl
			segControl.setTitle(AppState.sharedInstance.f_firstName, forSegmentAtIndex: 1)
			segControl.setEnabled(true, forSegmentAtIndex: 1)
			// set partner refs that don't rely on dayUserIsLookingAt
			partnerRef = ref.child("User-Deadlines").child(AppState.sharedInstance.f_firID!)
//			partnerDeadlineRef = partnerRef.child("Deadlines").child(self.dayUserIsLookingAt)
			owesRef = ref.child("Payments").child(AppState.sharedInstance.groupchat_id!).child("History")
			lastDatePaidRef = ref.child("Payments").child(AppState.sharedInstance.groupchat_id!).child("Last-Date-Paid")
			setupPaymentTracking()
		}
	}
	
	func setupPaymentTracking() {
		lastDatePaidRef.observeEventType(.Value) { (snapshot: FIRDataSnapshot) in
			let str_lpd = snapshot.value as! String
			self.owesRef.queryOrderedByKey().queryStartingAtValue(str_lpd).observeEventType(.Value) { (snapshot: FIRDataSnapshot) in
				var userTotal: Double = 0
				var partnerTotal: Double = 0
				for item in snapshot.children {
					if let userAmt = item.childSnapshotForPath(AppState.sharedInstance.userID).value as? Double {
						userTotal += userAmt
					}
					
					if let partnerAmt = item.childSnapshotForPath(AppState.sharedInstance.f_firID!).value as? Double {
						partnerTotal += partnerAmt
					}
				}
				
				let diff = partnerTotal - userTotal
				let absDiff = String(format: "%.2f", fabs(diff))
				if diff < 0 {
					self.amtOwedLabel.text = self.segControl.selectedSegmentIndex == 0 ?
						"-$\(absDiff)" :
						"+$\(absDiff)"
				} else if diff == 0 {
					self.amtOwedLabel.text =
						"$0"
				} else {
					self.amtOwedLabel.text = self.segControl.selectedSegmentIndex == 0 ?
						"+$\(absDiff)" :
						"-$\(absDiff)"
				}
			}
		}
	}
	
	// MARK: Set up user deadlines
	
	// set up the whole view, usually after a date change in calendar
	func setupUserView() {
		getDeadlinesForDay()
//		lockIfUserNeedsToPay()
	}
	
	// load table with deadlines for the day user is looking at
	func getDeadlinesForDay() {
		getDeadlines() { (result) -> () in
			self.determineOwedBalance(result)
		}
	}
	
	// get the deadlines
	func getDeadlines(completion: (result: Int)->()) {
		// (re)set ref that rely on dayUserIsLookingAt
		userDeadlinesRef = ref.child("User-Deadlines").child(AppState.sharedInstance.userID).child("Deadlines").child(self.dayUserIsLookingAt)
		
		// query by the "timeDue" property
		_userDeadlinesRefHandle = self.userDeadlinesRef.queryOrderedByChild("timeDue").observeEventType(.Value) { (snapshot: FIRDataSnapshot) in
			var newItems = [Deadline]()
			for item in snapshot.children {
				let deadlineItem = Deadline(snapshot: item as! FIRDataSnapshot)
				newItems.append(deadlineItem)
			}
			self.userDeadlines = newItems
			self.deadlineTable.reloadData()
			self.editButton.title = newItems.isEmpty ? "New" : "Edit"
			completion(result: self.userDeadlines.count)
		}
	}
	
	// determine how much the user owes for this particular day
	func determineOwedBalance(totalCount: Int) {
		let userOwesRef = self.owesRef.child(self.dayUserIsLookingAt).child(AppState.sharedInstance.userID)
		let missedCount = getMissedDeadlineCount()
		// if deadline count <= 5, every missed deadline costs $2.50/(deadline count).
		// otherwise, missed deadlines are charged at a flat rate of $0.50 each.
		if missedCount > 0 { 
			var amt = Double(missedCount)
			amt *= totalCount >= 5 ? 0.5 : (2.5/Double(totalCount))
			amt = Double(round(100*amt)/100)
			userOwesRef.setValue(amt)
		} else {
			userOwesRef.removeValue()
		}
	}
	
	// get count of missed deadlines
	func getMissedDeadlineCount() -> Int {
		var missedCount = 0
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
		for deadline in userDeadlines {
			let timeDue = formatter.dateFromString(deadline.timeDue!)!
			// if deadline is not complete, and is in the past
			if !deadline.complete && timeDue.timeIntervalSinceNow < 0 {
				missedCount += 1
			}
		}
		return missedCount
	}
	
	// checks if user needs to pay. if so, locks future days
	func lockIfUserNeedsToPay() {
		
		/*
	self.ref.child("Payments").child(AppState.sharedInstance.userID).child("Owed").queryOrderedByKey().queryStartingAtValue(str_maxDays).queryEndingAtValue(self.dayUserIsLookingAt).observeSingleEventOfType(.Value) { (snapshot: FIRDataSnapshot) in
			var tot: Double = 0
			var lastMissedDate = ""
			if let items = snapshot.value as? [String : String] {
				for item in items { tot += Double(item.1)! }
				lastMissedDate = items.keys.maxElement()!
			}
			self.total = tot
			
			if tot == 0 {
				self.amtOwedLabel.text! = "nothing owed :)"
				self.payButton.enabled = false
				self.blurView.hidden = true
				self.paymentCard.hidden = true
			} else { // user needs to pay
				self.amtOwedLabel.text! = "owed this day: $\(String(format: "%.2f", tot))"
				self.payButton.enabled = true
				
				// lock deadlines table if user is looking at a date after the missed deadline
				if lastMissedDate < self.dayUserIsLookingAt {
					self.blurView.hidden = false
					self.paymentCard.hidden = false
					self.paymentCardLabel.text = "You have missed deadlines!\nYou can't continue on until you pay \(AppState.sharedInstance.f_firstName!)."
				} else {
					self.blurView.hidden = true
					self.paymentCard.hidden = true
				}
			}
		}*/
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
		let strDay = self.dateFormatter.stringFromDate(date)
		self.dayUserIsLookingAt = strDay
		setupUserView()
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
		return segControl.selectedSegmentIndex == 0 ? userDeadlines.count : partnerDeadlines.count
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
		let deadlineItem = segControl.selectedSegmentIndex == 0 ? userDeadlines[indexPath.row] : partnerDeadlines[indexPath.row]
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
		if segControl.selectedSegmentIndex == 1 { // use not allowed to mark off partner's deadlines
			return
		}
		
		// get cell, its ref, and its status
		let cell = tableView.cellForRowAtIndexPath(indexPath)!
		let deadlineItem = self.userDeadlines[indexPath.row]
		let toggledCompletion = !deadlineItem.complete
		
		// update item
		self.toggleCellCheckbox(cell, isCompleted: toggledCompletion)
		let completeDict = [ "complete": toggledCompletion ]
		deadlineItem.ref?.updateChildValues(completeDict)
	}
}

// MARK: Navigation
extension DeadlinesViewController {
	override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
		return segControl.selectedSegmentIndex == 0 ? true : false
	}
	
	@IBAction func didChangeSegment(sender: AnyObject) {
		if segControl.selectedSegmentIndex == 0 { // user looking at their own deadlines
			// show edit and pay buttons
			self.editButton.tintColor = self.navigationController?.navigationBar.tintColor
			self.editButton.enabled = true
			self.payButton.tintColor = self.navigationController?.navigationBar.tintColor
			self.payButton.enabled = true
		} else { // user looking at partner's deadlines
			// jank way of hiding edit and pay buttons
			self.editButton.tintColor = UIColor.clearColor()
			self.editButton.enabled = false
			self.payButton.tintColor = UIColor.clearColor()
			self.payButton.enabled = false
		}
	}
	
	// called when starting to change from one screen in storyboard to next
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
		let navController = segue.destinationViewController as! UINavigationController
		let editDeadlinesVC = navController.topViewController as! EditDeadlinesViewController
		editDeadlinesVC.deadlines = userDeadlines
		editDeadlinesVC.date = dayUserIsLookingAt
		editDeadlinesVC.explanationEnabled = !userDeadlines.isEmpty
		editDeadlinesVC.title = (self.navigationItem.leftBarButtonItem?.title == "New") ? "New Schedule" : "Edit Schedule"
	}
	
	// saving when adding a new item or finished editing an old one
	@IBAction func unwindToDeadlinesList(sender: UIStoryboardSegue) {
		if let sourceViewController = sender.sourceViewController as? EditDeadlinesViewController {
			userDeadlinesRef.removeValue()
			for deadline in sourceViewController.deadlines {
				userDeadlinesRef.childByAutoId().setValue(deadline.toAnyObject())
			}
			
			// if user is part of a group chat and hasn't edited their deadlines
			if let chatId = AppState.sharedInstance.groupchat_id
				where sourceViewController.hasBeenEdited == true {
				let chatRef = FIRDatabase.database().reference().child("Chat").child(chatId).child("Messages")
				
				var status = " my schedule for \(sourceViewController.dateLabel.text!)"
				var message: String
				if sourceViewController.explanation == "" {
					status = "Set" + status
					message = status
				} else {
					status = "Edited" + status
					message = status + ". Reason: " + sourceViewController.explanation
				}

				// create the new entry
				let messageItem = [
					"id" : AppState.sharedInstance.userID,
					"displayName" : AppState.sharedInstance.firstName,
					"text" : message,
					"date" : detailedDateFormatter.stringFromDate(NSDate())
				]
				chatRef.childByAutoId().setValue(messageItem)
				
				// send a notification to partner
				sendNotification(AppState.sharedInstance.firstName + ": " + status)
			}
		}
	}
	
	@IBAction func didPressPayButton(sender: AnyObject) {
		self.lastDatePaidRef.setValue(self.dateFormatter.stringFromDate(NSDate()))
		
		// tell partner you've paid
		sendNotification(AppState.sharedInstance.firstName + " says they paid you $" + String(format: "%.2f", self.userTotal))
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