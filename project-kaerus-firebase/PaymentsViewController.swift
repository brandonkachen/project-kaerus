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
	@IBOutlet weak var userProfilePic: UIImageView!
	@IBOutlet weak var username: UILabel!
	@IBOutlet weak var userBalance: UILabel!
	@IBOutlet weak var friendProfilePic: UIImageView!
	@IBOutlet weak var friendName: UILabel!
	@IBOutlet weak var friendBalance: UILabel!
	@IBOutlet weak var paymentsTable: UITableView!
	
	// MARK: Properties
	var payments = [(String, Double)]()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		loadPaymentHistory()

		username.text = AppState.sharedInstance.firstName
		userProfilePic.image = AppState.sharedInstance.photo
		userBalance.text = "$0"
		
		// load partner data
		if let status = AppState.sharedInstance.partnerStatus where status == true {
			friendProfilePic.image = AppState.sharedInstance.f_photo
			friendName.text = AppState.sharedInstance.f_firstName
			friendBalance.text = "$0"
		}
    }
	
	func loadPaymentHistory() {
		
	}
	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}
	
	func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return false
	}
	
	// change header height
	func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 40.0
	}
	
	// header title
	func tableView( tableView : UITableView,  titleForHeaderInSection section: Int) -> String {
		let day = "DAY 1"
		return day
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cellIdentifier = "PaymentHistoryTableViewCell"
		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! PaymentHistoryTableViewCell
		return configureCell(cell, indexPath: indexPath)
	}
	
	func configureCell(cell: PaymentHistoryTableViewCell, indexPath: NSIndexPath) -> UITableViewCell {
//		let paymentItem = payments[indexPath.row]
		
		return cell
	}
}
