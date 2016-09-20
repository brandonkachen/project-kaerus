//
//  CostOfEachDayViewController.swift
//  
//
//  Created by Brandon Chen on 9/14/16.
//
//

import UIKit
import FirebaseDatabase

class CostOfEachDayViewController: UIPageViewController {
	var costEachDayRef: FIRDatabaseReference!
	
	@IBOutlet weak var costText: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
		
		costEachDayRef = FIRDatabase.database().reference().child("Payments-User-Settings").child(AppState.sharedInstance.groupchat_id!).child("Cost-Of-Each-Day")
		costEachDayRef.observe(.value) { (snapshot: FIRDataSnapshot?) in
			if let cost = snapshot?.value as? Double {
				self.costText.text = cost.description
			} else {
				self.costText.text = ""
			}
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
    }

}
