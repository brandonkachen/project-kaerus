//
//  EditDeadlinesViewController.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/13/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit
import FirebaseDatabase

class EditDeadlinesViewController: UIViewController {
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var editDeadlineTable: UITableView!
	@IBOutlet weak var dateView: UIView!

	var deadlines = [Deadline]()
	var date : String!
	var explanation = ""
	weak var enableSaveButton : UIAlertAction?
	var hasBeenEdited = false // used to tell if the user has edited any deadlines
	var explanationEnabled: Bool! // used to tell if the user has set any deadlines before

    override func viewDidLoad() {
        super.viewDidLoad()
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yyyy-MM-dd Z"
		let d = formatter.dateFromString(date)!
		formatter.dateFormat = "MMMM d"
		let sd = formatter.stringFromDate(d) + d.daySuffix()
		dateLabel.text = sd
		
		dateView.layer.shadowOffset = CGSizeMake(1, 1)
		dateView.layer.shadowColor = UIColor.lightGrayColor().CGColor
		dateView.layer.shadowOpacity = 0.5
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
    // MARK: Navigation

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
		if segue.identifier == "editItem" { // Edit item
			let deadlinesViewController = segue.destinationViewController as! AddDeadlineViewController
			if let selectedItemCell = sender as? DeadlinesTableViewCell {
				let indexPath = editDeadlineTable.indexPathForCell(selectedItemCell)!
				let selectedDeadline = deadlines[indexPath.row]
				deadlinesViewController.deadline = selectedDeadline
			}
		}
	}
	
	// saving when adding a new item or finished editing an old one
	@IBAction func unwindToEditDeadlinesList(sender: UIStoryboardSegue) {
		if let sourceViewController = sender.sourceViewController as? AddDeadlineViewController, deadline = sourceViewController.deadline {
			if let selectedIndexPath = editDeadlineTable.indexPathForSelectedRow { // Update current item
				deadlines[selectedIndexPath.row] = deadline
			} else { // Add a new item to the list
				deadlines.append(deadline)
			}
			hasBeenEdited = true
			deadlines.sortInPlace(){ $0.timeDue < $1.timeDue }
			editDeadlineTable.reloadData()
		}
	}
	
	@IBAction func didPressDoneButton(sender: AnyObject) {
		if explanationEnabled && hasBeenEdited {
			let messageStr = "Please explain why you're changing your schedule"
			let alert = UIAlertController(title: nil, message: messageStr, preferredStyle: UIAlertControllerStyle.Alert)
			
			alert.addTextFieldWithConfigurationHandler({(textField: UITextField) in
				textField.placeholder = "because..."
				textField.addTarget(self, action: #selector(self.textChanged(_:)), forControlEvents: .EditingChanged)
			})
			
			let backButton = UIAlertAction(title: "Back", style: UIAlertActionStyle.Cancel, handler: { (_) -> Void in
				self.resignFirstResponder()
			})
			
			let saveButton = UIAlertAction(title: "Save", style: UIAlertActionStyle.Default, handler: { (_) -> Void in
				let textfield = alert.textFields!.first!
				self.explanation = textfield.text!
				self.performSegueWithIdentifier("backToDeadlinesList", sender: self)
			})
			
			alert.addAction(backButton)
			alert.addAction(saveButton)
			
			self.enableSaveButton = saveButton
			saveButton.enabled = false
			self.presentViewController(alert, animated: true, completion: nil)
		} else {
			self.performSegueWithIdentifier("backToDeadlinesList", sender: self)
		}
	}
	
	func textChanged(sender:UITextField) {
		self.enableSaveButton?.enabled = (sender.text! != "")
	}
}

// MARK: UITableView Delegate methods
extension EditDeadlinesViewController {
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return deadlines.count
	}
	
	func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}
	
	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return UITableViewAutomaticDimension
	}
	
	func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return UITableViewAutomaticDimension
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cellIdentifier = "EditDeadlinesTableViewCell"
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
	
	// swiping horizontally shows "delete" button. pressing it will remove item
	func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		let delete_button = UITableViewRowAction(style: .Destructive, title: "delete") { (action, indexPath) in
			self.hasBeenEdited = true
			self.deadlines.removeAtIndex(indexPath.row)
			self.editDeadlineTable.reloadData()
		}
		return [delete_button]
	}
}