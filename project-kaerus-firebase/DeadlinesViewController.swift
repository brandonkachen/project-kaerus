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
	@IBOutlet weak var payButton: UIButton!
	
	var userDeadlines = [Deadline]()
	var partnerDeadlines = [Deadline]()
	var ref, dateRef, userRef, userDeadlinesRef, partnerRef, partnerDeadlinesRef, paymentsHistoryRef, lastDayUserSetDeadlinesRef, dayUserLastSawRef, confirmedLastDayPaidRef, unconfirmedLastDayPaidRef, owedTotalsRef: FIRDatabaseReference!
	private var _userDeadlinesRefHandle, _partnerDeadlinesRefHandle, _lastDayUserSetDeadlinesRefHandle: FIRDatabaseHandle!
	var dateUserIsLookingAt: String! // set by the 'day' variable in User-Deadlines
	var userTotal: Double = 0
	var partnerTotal: Double = 0
	var shouldLock = false
	var lockDate: String! = ""
	var str_lastDatePaid: String! = ""
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// set up refs that don't rely on dayUserIsLookingAt for user
		ref = FIRDatabase.database().reference()
		setPartnerStuff()

//		fetchConfig()
		logViewLoaded()
		
		// get today's deadlines on initial load
		dateFormatter.dateFormat = "yyyy-MM-dd Z"
		dateUserIsLookingAt = dateFormatter.stringFromDate(NSDate())
		
		// used for timestamps or where time precision is needed
		detailedDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SS"
		detailedDateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
		
		calendarView.dataSource = self
		calendarView.delegate = self
		calendarView.registerCellViewXib(fileName: "CellView")
		
		dateRef = ref.child("User-Deadlines").child(AppState.sharedInstance.userID).child("Date-User-Is-Looking-At")
		dateRef.observeSingleEventOfType(.Value) { (startDateSnap: FIRDataSnapshot) in
			if let date = startDateSnap.value as? String {
				self.dateUserIsLookingAt = date
			} else {
				let dateToAdd = self.dateFormatter.stringFromDate(NSDate())
				self.dateRef.setValue(dateToAdd)
				self.dateUserIsLookingAt = dateToAdd
			}
			let dateToShow = self.dateFormatter.dateFromString(self.dateUserIsLookingAt)!
			self.calendarView.selectDates([dateToShow])
			self.calendarView.scrollToDate(dateToShow)
		}
		
		amtOwedView.layer.shadowOffset = CGSizeMake(1, 1)
		amtOwedView.layer.shadowColor = UIColor.lightGrayColor().CGColor
		amtOwedView.layer.shadowOpacity = 0.5
		
		paymentCard.layer.shadowOffset = CGSizeMake(1, 1)
		paymentCard.layer.shadowColor = UIColor.lightGrayColor().CGColor
		paymentCard.layer.shadowOpacity = 0.5
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.partnerStatusChanged(_:)), name: "PartnerInfoChanged_Deadlines", object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.paymentSettingsChanged(_:)), name: "PaymentSettingsChanged", object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector:#selector(self.reloadData(_:)), name:
			UIApplicationWillEnterForegroundNotification, object: nil)

	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.tabBarController?.tabBar.items![1].badgeValue = nil
		AppState.sharedInstance.numOfUnseenPartnerDeadlineChanges = 0
		self.deadlineTable.reloadData()
	}
	
	deinit {
		self.userDeadlinesRef.removeObserverWithHandle(_userDeadlinesRefHandle)
		if partnerDeadlinesRef != nil {
			self.partnerDeadlinesRef.removeObserverWithHandle(_partnerDeadlinesRefHandle)
		}
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	func partnerStatusChanged(_: NSNotification) {
		setPartnerStuff()
	}
	
	func paymentSettingsChanged(_: NSNotification) {
		if segControl.selectedSegmentIndex == 0 {
			lockIfUserNeedsToPay()
		}
	}
	
	func reloadData(_: NSNotification) {
		self.deadlineTable.reloadData()
	}
	
	func logViewLoaded() {
		FIRCrashMessage("DeadlineVC loaded")
	}
	
	// MARK: Set up partner's deadline stuff
	
	func setPartnerStuff() {
		if AppState.sharedInstance.groupchat_id == nil {	// no partner, so disable partner button in segControl and remove observer if possible
			segControl.setTitle("Partner", forSegmentAtIndex: 1)
			segControl.setEnabled(false, forSegmentAtIndex: 1)
			segControl.selectedSegmentIndex = 0
			partnerDeadlines.removeAll()
			amtOwedLabel.text = "you don't have a partner!"
			
			if partnerDeadlinesRef != nil {
				self.partnerDeadlinesRef.removeObserverWithHandle(_partnerDeadlinesRefHandle)
			}
			
			// get rid of other refs here
			
			partnerDeadlinesRef = nil
			partnerRef = nil
		} else { // user has partner - load their data separately from user's
			// set segControl
			segControl.setTitle(AppState.sharedInstance.f_firstName, forSegmentAtIndex: 1)
			segControl.setEnabled(true, forSegmentAtIndex: 1)
			// set partner refs that don't rely on dayUserIsLookingAt
			partnerRef = ref.child("User-Deadlines").child(AppState.sharedInstance.f_firID!)
			paymentsHistoryRef = ref.child("Payments").child(AppState.sharedInstance.groupchat_id!).child("History")
			confirmedLastDayPaidRef = ref.child("Payments").child(AppState.sharedInstance.groupchat_id!).child("Last-Date-Paid-Confirmed")
			unconfirmedLastDayPaidRef = ref.child("Payments").child(AppState.sharedInstance.groupchat_id!).child("Last-Date-Paid-Unconfirmed").child(AppState.sharedInstance.f_firID!) // check if partner has made a claim about payments
			owedTotalsRef = ref.child("Payments").child(AppState.sharedInstance.groupchat_id!).child("Owed-Totals")
			checkIfUserNeedsToConfirmPayment()
			setupPaymentTracking()
		}
	}
	
	func checkIfUserNeedsToConfirmPayment() {
		unconfirmedLastDayPaidRef.observeEventType(.Value) { (snapshot: FIRDataSnapshot!) in
			if let unconfirmedPaymentDate = snapshot.value as? String {
				let messageTitle = "Payment Confirmation"
				let messageStr = "Has your partner paid you for exceeding the money limit?"
				let alert = UIAlertController(title: messageTitle, message: messageStr, preferredStyle: UIAlertControllerStyle.Alert)
				
				let backButton = UIAlertAction(title: "No", style: UIAlertActionStyle.Cancel, handler: { (_) -> Void in
					self.resignFirstResponder()
					self.unconfirmedLastDayPaidRef.removeValue()
				})
				
				let saveButton = UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default, handler: { (_) -> Void in
					self.resignFirstResponder()
					
					// update partner's payment confirmation info
					self.unconfirmedLastDayPaidRef.removeValue()
					self.confirmedLastDayPaidRef.child(AppState.sharedInstance.f_firID!).setValue(unconfirmedPaymentDate)
					self.owedTotalsRef.child(AppState.sharedInstance.f_firID!).setValue(0)
				})
				
				alert.addAction(backButton)
				alert.addAction(saveButton)
				
				self.presentViewController(alert, animated: true, completion: nil)
			}
		}
	}
	
	// used only for user, to tell if they must pay
	func lockIfUserNeedsToPay() {
//		let totalOwed = self.segControl.selectedSegmentIndex == 0 ? self.userTotal : self.partnerTotal
		
		// if user owes more than the limit allows, and is looking at their own tab
		if self.userTotal >= AppState.sharedInstance.maxLimit && self.segControl.selectedSegmentIndex == 0 {
			self.amtOwedLabel.text = "you must pay: "
			self.amtOwedLabel.textColor = UIColor.redColor()
			self.shouldLock = true
			if self.lockDate.isEmpty == false && self.dateUserIsLookingAt > self.lockDate {
				self.lock()
				self.editButton.enabled = false
			}
		} else { // user doesn't need to pay
			self.shouldLock = false
			self.unlock()
			self.amtOwedLabel.textColor = UIColor.blackColor()
			self.editButton.enabled = true
			if self.userTotal == 0 {
				self.amtOwedLabel.text = "nothing owed :)"
				return
			}
			self.amtOwedLabel.text = "owed: "
		}
		let formattedTot = String(format: "%.2f", fabs(self.userTotal))
		self.amtOwedLabel.text! += "$" + formattedTot
	}
	
	func setupPaymentTracking() {
		func calculateTotal(snapshot: FIRDataSnapshot) -> Double {
			var total: Double = 0
			if let items = snapshot.value as? [String : Double] {
				for item in items { total += item.1 }
			}
			return total
		}
		
		confirmedLastDayPaidRef.child(AppState.sharedInstance.userID).observeEventType(.Value) { (snapshot: FIRDataSnapshot) in
			self.str_lastDatePaid = snapshot.value as! String
			
			// get the day after last paid date, so query can start there
			let lastPaidDate = self.dateFormatter.dateFromString(self.str_lastDatePaid)!
			let nextDay = lastPaidDate.nextDay()
			let str_nextDay = self.dateFormatter.stringFromDate(nextDay)
			
			// detect changes in user history from str_nextDay onwards
			self.paymentsHistoryRef.child(AppState.sharedInstance.userID).queryOrderedByKey().queryStartingAtValue(str_nextDay).observeEventType(.Value)
			{ (snapshot: FIRDataSnapshot) in
				self.userTotal = calculateTotal(snapshot)
				self.owedTotalsRef.child(AppState.sharedInstance.userID).setValue(self.userTotal)
				
				// janky way of getting the last date user has set deadlines and locking
				self.lastDayUserSetDeadlinesRef = self.ref.child("User-Deadlines").child(AppState.sharedInstance.userID).child("Deadlines")
				self.lastDayUserSetDeadlinesRef.queryOrderedByKey().queryLimitedToLast(1).observeSingleEventOfType(.Value) { (snapshot: FIRDataSnapshot) in
					// only one item in snapshot.children
					for item in snapshot.children {
						self.lockDate = item.key!
					}
					self.lockIfUserNeedsToPay()
				}
			}
			
			// check for updated partner owed amounts
			self.owedTotalsRef.child(AppState.sharedInstance.f_firID!).observeEventType(.Value) { (snapshot: FIRDataSnapshot) in
				if let tot = snapshot.value as? Double {
					self.partnerTotal = tot
					self.lockIfUserNeedsToPay()
				}
			}
		}
	}
	
	// hide deadlines and prompt user to pay
	func lock() {
		self.blurView.hidden = false
		self.paymentCard.hidden = false
	}
	
	// hide payment stuff; show deadlines
	func unlock() {
		self.blurView.hidden = true
		self.paymentCard.hidden = true
	}
	
	// MARK: Set up user deadlines
	
	// set up the user's view, usually after a date change in calendar
	func setupUserView() {
		if _userDeadlinesRefHandle != nil {
			self.userDeadlinesRef.removeObserverWithHandle(_userDeadlinesRefHandle)
		}
		getUserDeadlines() { (result) -> () in
			if AppState.sharedInstance.partnerStatus == true {
				self.determineOwedBalance(result)
				self.lockIfUserNeedsToPay()
			}
		}
	}
	
	// set up the user's view, usually after a date change in calendar
	func setupPartnerView() {
		if partnerDeadlinesRef != nil {
			self.partnerDeadlinesRef.removeObserverWithHandle(_partnerDeadlinesRefHandle)
		}
		partnerDeadlinesRef = partnerRef.child("Deadlines").child(self.dateUserIsLookingAt)
		// query by the "timeDue" property
		_partnerDeadlinesRefHandle = partnerDeadlinesRef.queryOrderedByChild("timeDue").observeEventType(.Value) { (snapshot: FIRDataSnapshot) in
			self.partnerDeadlines = self.getNewItems(snapshot)
			if self.segControl.selectedSegmentIndex == 1 {
				self.deadlineTable.reloadData()
				let formattedTot = String(format: "%.2f", fabs(self.partnerTotal))
				self.amtOwedLabel.textColor = UIColor.blackColor()
				self.amtOwedLabel.text! = self.partnerTotal == 0 ? "nothing owed :)" : "owed: $" + formattedTot
				self.shouldLock = false
				self.unlock()
			}
		}
	}
	
	// returns any new deadlines
	func getNewItems(snap: FIRDataSnapshot) -> [Deadline] {
		var newItems = [Deadline]()
		for item in snap.children {
			let deadlineItem = Deadline(snapshot: item as! FIRDataSnapshot)
			newItems.append(deadlineItem)
		}
		return newItems
	}
	
	// get the deadlines
	func getUserDeadlines(completion: (result: Int)->()) {
		userDeadlinesRef = ref.child("User-Deadlines").child(AppState.sharedInstance.userID).child("Deadlines").child(self.dateUserIsLookingAt)
		// query by the "timeDue" property
		
		_userDeadlinesRefHandle = userDeadlinesRef.queryOrderedByChild("timeDue").observeEventType(.Value) { (snapshot: FIRDataSnapshot) in
			self.userDeadlines = self.getNewItems(snapshot)
			self.deadlineTable.reloadData()
			self.editButton.title = self.userDeadlines.isEmpty ? "New" : "Edit"
			completion(result: self.userDeadlines.count)
		}
	}
	
	// determine how much the user owes for this particular day
	func determineOwedBalance(totalCount: Int) {
		let userOwesRef = self.paymentsHistoryRef.child(AppState.sharedInstance.userID).child(self.dateUserIsLookingAt)
		let missedCount = getMissedDeadlineCount()
		
		if missedCount > 0 { 
			var amt = Double(missedCount)
			if AppState.sharedInstance.splitCost && AppState.sharedInstance.flatRate {
				if totalCount <= AppState.sharedInstance.flatRate_AfterNumDeadlines {
					// every missed deadline costs: $(costOfEachDay)/(total deadline count)
					amt *= (AppState.sharedInstance.costOfEachDay/Double(totalCount))
				} else { // otherwise, missed deadlines are charged at a flat rate of $(flatRate_EachDeadlineCost) each.
					amt *= AppState.sharedInstance.flatRate_EachDeadlineCost
				}
			} else { // if any deadline was missed, the entire day's money is lost
				amt = AppState.sharedInstance.costOfEachDay
			}
			amt = Double(round(100*amt)/100) // round value to the nearest cent
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
		let secondDate = NSCalendar.currentCalendar()
			.dateByAddingUnit(
				.Month,
				value: 1,
				toDate: NSDate(),
				options: []
		)!
		let numberOfRows = 2
		let aCalendar = NSCalendar.currentCalendar() // Properly configure your calendar to your time zone here
		
		return (startDate: firstDate, endDate: secondDate, numberOfRows: numberOfRows, calendar: aCalendar)
	}
	
	func calendar(calendar: JTAppleCalendarView, isAboutToDisplayCell cell: JTAppleDayCellView, date: NSDate, cellState: CellState) {
		(cell as! CellView).setupCellBeforeDisplay(cellState, date: date)
	}
	
	func calendar(calendar: JTAppleCalendarView, didSelectDate date: NSDate, cell: JTAppleDayCellView?, cellState: CellState) {
		let strDay = self.dateFormatter.stringFromDate(date)
		self.dateUserIsLookingAt = strDay
		if self.segControl.selectedSegmentIndex == 0 {
			setupUserView() // show user deadlines
			self.dateUserIsLookingAt <= self.str_lastDatePaid ? disableEditButton() : enableEditButton() // enable or disable edit button

			// lock or unlock the view
			if shouldLock == true && self.dateUserIsLookingAt > self.lockDate  {
				lock()
				self.editButton.enabled = false
			} else {
				unlock()
				self.editButton.enabled = true
			}
		} else {
			disableEditButton()
			setupPartnerView()
		}
		self.dateRef.setValue(strDay)
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
		// use not allowed to mark off partner's deadlines
		if segControl.selectedSegmentIndex == 1 { 
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
	
	func enableEditButton() {
		// show edit and pay buttons
		self.editButton.tintColor = self.navigationController?.navigationBar.tintColor
		self.editButton.enabled = true
	}
	
	func disableEditButton() {
		// jank way of hiding edit and pay buttons
		self.editButton.tintColor = UIColor.clearColor()
		self.editButton.enabled = false
	}
	
	@IBAction func didChangeSegment(sender: AnyObject) {
		if segControl.selectedSegmentIndex == 0 { // user looking at their own deadlines
			enableEditButton()
			self.setupUserView()
		} else { // user looking at partner's deadlines
			disableEditButton()
			self.setupPartnerView()
		}
		self.deadlineTable.reloadData()
	}
	
	// called when starting to change from one screen in storyboard to next
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
		let navController = segue.destinationViewController as! UINavigationController
		let editDeadlinesVC = navController.topViewController as! EditDeadlinesViewController
		editDeadlinesVC.deadlines = userDeadlines
		editDeadlinesVC.startDate = self.dateFormatter.dateFromString(dateUserIsLookingAt)
		editDeadlinesVC.explanationEnabled = !userDeadlines.isEmpty
		editDeadlinesVC.title = (self.navigationItem.leftBarButtonItem?.title == "New") ? "New Schedule" : "Edit Schedule"
	}
	
	// saving when adding a new item or finished editing an old one
	@IBAction func unwindToDeadlinesList(sender: UIStoryboardSegue) {
		if let sourceViewController = sender.sourceViewController as? EditDeadlinesViewController {
			var listOfDeadlines = ""
			let longFormatter = NSDateFormatter()
			let shortFormatter = NSDateFormatter()
			longFormatter.dateFormat = "yyyy-MM-dd HH:mmZ"
			shortFormatter.dateFormat = "h:mm a"

			userDeadlinesRef.removeValue()
			for deadline in sourceViewController.deadlines {
				userDeadlinesRef.childByAutoId().setValue(deadline.toAnyObject())
				
				// configure the date to show
				let timeDue = longFormatter.dateFromString(deadline.timeDue!)
				let timeDueText = shortFormatter.stringFromDate(timeDue!)
				listOfDeadlines += deadline.text + " - " + timeDueText + "\n"
			}
			if !listOfDeadlines.isEmpty {
				listOfDeadlines.removeAtIndex(listOfDeadlines.endIndex.predecessor()) // get rid of last '\n'
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

				if !listOfDeadlines.isEmpty {
					message += "\n\n"
				}
				message += listOfDeadlines
				
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
		sendNotification(AppState.sharedInstance.firstName + " claims to have paid you $" + (userTotal - partnerTotal).description + ". Please confirm this.")
		ref.child("Payments").child(AppState.sharedInstance.groupchat_id!).child("Last-Date-Paid-Unconfirmed").child(AppState.sharedInstance.userID).setValue(self.lockDate)
		self.payButton.hidden = true
		self.paymentCardLabel.text = "Payment confirmation sent!\n\nYour partner must confirm your payment before you can continue."
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
