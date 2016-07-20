//
//  SettingsTableViewController.swift
//
//  Created by Brandon Chen on 7/16/16.
//
//

import UIKit
import FirebaseAuth

class SettingsTableViewController: UITableViewController {
	
	var savedSelectedIndexPath: NSIndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		self.savedSelectedIndexPath = nil
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		if let indexPath = self.savedSelectedIndexPath {
			self.tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: .None)
		}
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.savedSelectedIndexPath = tableView.indexPathForSelectedRow
		if let indexPath = self.savedSelectedIndexPath {
			self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
		}
	}
	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	
	// MARK:- sign out
	
	@IBAction func signOut(sender: AnyObject) {
		let firebaseAuth = FIRAuth.auth()
		do {
			try firebaseAuth?.signOut()
			AppState.sharedInstance.signedIn = false
			
			let secondViewController = self.storyboard!.instantiateViewControllerWithIdentifier("loginViewController") as! LoginViewController
			self.navigationController!.pushViewController(secondViewController, animated: true)
			self.tabBarController!.tabBar.hidden = true
			self.navigationController!.navigationBarHidden = true
//			self.navigationController!.popToRootViewControllerAnimated(true)
			
		} catch let signOutError as NSError {
			print ("Error signing out: \(signOutError)")
		}
	}
    // MARK: - Table view data source
	
//	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String?
//	{
//		return
//	}
	
//	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
//		self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
//	}

//    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
//        return 1
//    }

//    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return settingItems.count
//    }
//
//    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
//		let cellIdentifier = "SettingTableViewCell"
//		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! SettingTableViewCell
//		cell.titleLabel.text = settingItems[indexPath.row]
//		cell.subtitleLabel.text = ""
//        return cell
//    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
