//
//  CostOfEachDayTableViewController.swift
//  
//
//  Created by Brandon Chen on 9/19/16.
//
//

import UIKit
import FirebaseDatabase

class CostOfEachDayTableViewController: UITableViewController {
	@IBOutlet weak var costOfEachDayTextField: UITextField!
	@IBOutlet weak var maxLimitTextField: UITextField!
	@IBOutlet weak var splitCostSwitch: UISwitch!
	@IBOutlet weak var flatRateSwitch: UISwitch!
	@IBOutlet weak var flatRate_EachDeadlineCost: UITextField!
	@IBOutlet weak var flatRate_NumOfDeadlines: UITextField!
	
	var costRef: FIRDatabaseReference!
	let AS = AppState.sharedInstance

    override func viewDidLoad() {
        super.viewDidLoad()
		costRef = FIRDatabase.database().reference().child("Payments").child(AppState.sharedInstance.groupchat_id!).child("Settings")
		costOfEachDayTextField.text = AS.costOfEachDay.description
		maxLimitTextField.text = AS.maxLimit.description
		splitCostSwitch.on = AS.splitCost
		flatRateSwitch.on = AS.flatRate
		flatRate_EachDeadlineCost.text = AS.flatRate_EachDeadlineCost.description
		flatRate_NumOfDeadlines.text = AS.flatRate_AfterNumDeadlines.description
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	@IBAction func didChangeCostOfEachDay(sender: AnyObject) {
		
	}
	
	override func willMoveToParentViewController(parent: UIViewController?) {
		super.willMoveToParentViewController(parent)
		if parent == nil {
			AppState.sharedInstance.setCostData(costOfEachDayTextField.text!, maxLimit: maxLimitTextField.text!, splitCost: splitCostSwitch.on, flatRate: flatRateSwitch.on, flatRate_AfterNumDeadlines: flatRate_NumOfDeadlines.text!, flatRate_EachDeadlineCost: flatRate_EachDeadlineCost.text!)
		
			let paymentSettingsDict = [
				"Cost-Per-Day" : AS.costOfEachDay,
				"Max-Limit" : AS.maxLimit,
				"Split-Cost" : AS.splitCost,
				"Flat-Rate" : [
					"Enabled" : AS.flatRate,
					"After-Num-Deadlines" : AS.flatRate_AfterNumDeadlines,
					"Each-Deadline-Cost" : AS.flatRate_EachDeadlineCost
				]
			]
			costRef.setValue(paymentSettingsDict)
			
			// send notification to partner
			sendNotification(AppState.sharedInstance.f_name! + " has changed your payment settings.")
		}
	}
}
