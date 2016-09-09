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
	@IBOutlet weak var partnerProfilePic: UIImageView!
	@IBOutlet weak var partnerName: UILabel!
	@IBOutlet weak var partnerBalance: UILabel!
	
	var ref, userBalanceRef, partnerBalanceRef: FIRDatabaseReference!
	
	// MARK: Properties
	var payments = [(String, Double)]()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		username.text = AppState.sharedInstance.firstName
		userProfilePic.image = AppState.sharedInstance.photo
		userBalance.text = "$0"
		
		// load partner data
		if AppState.sharedInstance.groupchat_id != nil {
			partnerProfilePic.image = AppState.sharedInstance.f_photo
			partnerName.text = AppState.sharedInstance.f_firstName
			ref = FIRDatabase.database().reference().child("Payments").child(AppState.sharedInstance.groupchat_id!).child("History")
			userBalanceRef = ref.child(AppState.sharedInstance.userID)
			partnerBalanceRef = ref.child(AppState.sharedInstance.f_firID!)
			
			userBalanceRef.observeEventType(.Value) { (snapshot: FIRDataSnapshot!) in
				self.userBalance.text = "$" + self.calculateTotal(snapshot).description
			}
			
			partnerBalanceRef.observeEventType(.Value) { (snapshot: FIRDataSnapshot!) in
				self.partnerBalance.text = "$" + self.calculateTotal(snapshot).description
			}
		}
    }
	
	func calculateTotal(snapshot: FIRDataSnapshot) -> Double {
		var total: Double = 0
		if let items = snapshot.value as? [String : Double] {
			for item in items { total += item.1 }
		}
		return total
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
