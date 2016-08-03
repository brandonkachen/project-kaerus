//
//  PaymentsTableViewController.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/3/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit

class PaymentsTableViewController: UITableViewController {
	
	
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
	
	// Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("PaymentsTableViewCell", forIndexPath: indexPath) as! PaymentsTableViewCell

		let userPhoto = UIImage(data: NSData(contentsOfURL: AppState.sharedInstance.photoUrl!)!)
		cell.profilePic.image = userPhoto
		cell.profilePic.layer.cornerRadius = cell.profilePic.frame.size.width / 2
		cell.profilePic.clipsToBounds = true
		
		cell.nameLabel.text = AppState.sharedInstance.username
		cell.totalBalance.text = "total balance: $1.08"
		cell.owedBalance.text = "money owed this week: $1.00"

        return cell
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
