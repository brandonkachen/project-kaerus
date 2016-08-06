//
//  PaymentsViewController.swift
//  
//
//  Created by Brandon Chen on 8/5/16.
//
//

import UIKit
import Firebase

class PaymentsViewController: UIViewController {
	@IBOutlet weak var segmentedControl: UISegmentedControl!
	@IBOutlet weak var profilePic: UIImageView!
	@IBOutlet weak var name: UILabel!
	@IBOutlet weak var balance: UILabel!
	@IBOutlet weak var owedBalance: UILabel!
	@IBOutlet weak var payButton: UIButton!
	@IBOutlet weak var missedDeadlinesTable: UITableView!

	
	// MARK: Properties
	var missedDeadlines = [Deadline]()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		name.text = AppState.sharedInstance.name
		profilePic.image = AppState.sharedInstance.photo
		
		if let status = AppState.sharedInstance.partnerStatus where status == true { // user has a partner
			segmentedControl.setTitle(AppState.sharedInstance.f_firstName, forSegmentAtIndex: 1)
		} else { // no friend, gray out 'partner' segment
			segmentedControl.setEnabled(false, forSegmentAtIndex: 1)
		}
		loadMissedDeadlines(AppState.sharedInstance.userID)
    }

	@IBAction func didChangeSegment(sender: AnyObject) {
		if segmentedControl.selectedSegmentIndex == 0 { // user looking at their deadlines
			name.text = AppState.sharedInstance.name
			profilePic.image = AppState.sharedInstance.photo
			
		} else { // user looking at partner's deadlines
			name.text = AppState.sharedInstance.f_name
			profilePic.image = AppState.sharedInstance.f_photo!
		}
	}
	
	func loadMissedDeadlines(id: String) {
		
	}
	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
//	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//		return deadlines.count
//	}
	
	func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		// user is only allowed to mark "finished" or delete their own deadlines
		return segmentedControl.selectedSegmentIndex == 0 ? true : false
	}
	
	// change header height
	func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 40.0
	}
	
	// header title
//	func tableView( tableView : UITableView,  titleForHeaderInSection section: Int) -> String {
//		let day = "DAY " + String(dayUserIsLookingAt)
//		return day
//	}
	
	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return UITableViewAutomaticDimension
	}
	
	func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return UITableViewAutomaticDimension
	}
	
//	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
//		let cellIdentifier = "DeadlinesTableViewCell"
//		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! DeadlinesTableViewCell
//		return //configureCell(cell, indexPath: indexPath)
//	}
//	
}
