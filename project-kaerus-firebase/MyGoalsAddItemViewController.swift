// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import UIKit

protocol GoalsItemDelegate {
	func insertItem(text : String, timeDue : NSDate)
}

class MyGoalsAddItemViewController: UIViewController,  UIBarPositioningDelegate, UITextFieldDelegate, UINavigationControllerDelegate {
	
	@IBOutlet weak var text: UITextField!
	@IBOutlet weak var UserSetTime: UIDatePicker!
	@IBOutlet weak var saveButton: UIBarButtonItem!
	
	var delegate : GoalsItemDelegate?
	
	/*  This value is either passed by `MealTableViewController` in `prepareForSegue(_:sender:)`,
	or constructed as part of adding a new meal. */
	var goal: Goal?
	var goalComplete: Bool?
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		self.text.delegate = self
		
		// user wants to edit a goal
		if let _ = goal {
			navigationItem.title = "Edit Your Goal"
			
			text.text = goal?.text
			
			let timeFormatter = NSDateFormatter()
			timeFormatter.dateFormat = "yyyy-MM-dd HH:mmZ"
			let timeDue = timeFormatter.dateFromString((goal?.timeDue)!)
			
			UserSetTime.date = timeDue!
			goalComplete = goal?.complete
		}
		else { // user wants to add a goal
			let now = NSDate()
			
			// convert to double, take floor and multiply by 15
			let minuteFormatter = NSDateFormatter()
			minuteFormatter.dateFormat = "mm"
			let minute = (minuteFormatter.stringFromDate(now) as NSString).doubleValue
			let roundedMinute = floor(minute/15.0) * 15.0
			
			// get difference between current and floor'd time for dateByAddingUnit
			let difference = roundedMinute - minute
			
			// add the difference to the current time's minute. Clunky, but the most compact way to do this AFAIK
			let floorTime = NSCalendar.currentCalendar().dateByAddingUnit(
				.Minute,
				value: Int(difference),
				toDate: now,
				options: NSCalendarOptions.MatchStrictly)
			
			UserSetTime.date = floorTime!
			goalComplete = false
			
			self.text.becomeFirstResponder()
		}
		
		// used to know when textfields are being written into
		text.addTarget(self, action: #selector(MyGoalsAddItemViewController.textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
	}
	
	@IBAction func timePickerAction(sender: UIDatePicker) {
	}
	
	@IBAction func cancelPressed(sender : UIBarButtonItem) {
		if let _ = goal { // push presentation; editing an item
			navigationController!.popViewControllerAnimated(true)
		} else { // modal presentation; adding an item
			dismissViewControllerAnimated(true, completion: nil)
		}
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if saveButton === sender {
			let goalName = text.text!
			let formatter = NSDateFormatter()
			formatter.dateFormat = "yyyy-MM-dd HH:mmZ"
			let timeDue = formatter.stringFromDate(UserSetTime.date)
			goal = Goal(text: goalName, timeDue: timeDue, complete: self.goalComplete!)
		}
	}
	
	func checkConditionsForSaveButton() {
		// Disable the Save button if the text field is empty.
		let input = text.text ?? ""
		saveButton.enabled = !input.isEmpty
	}
	
	func textFieldDidBeginEditing(textField: UITextField) {
		checkConditionsForSaveButton()
	}
	
	func textFieldDidChange(textField: UITextField) {
		checkConditionsForSaveButton()
	}
	
	func textFieldShouldEndEditing(textField: UITextField) -> Bool
	{
		return true
	}
	
	func textFieldShouldReturn(textField: UITextField) -> Bool
	{
		textField.resignFirstResponder()
		return true
	}
}