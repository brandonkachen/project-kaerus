//
//  CellView.swift
//  testApplicationCalendar
//
//  Created by Jay Thomas on 2016-03-04.
//  Copyright © 2016 OS-Tech. All rights reserved.
//


import JTAppleCalendar

class CellView: JTAppleDayCellView {
	@IBInspectable var todayColor: UIColor!
	@IBInspectable var normalDayColor: UIColor!
	@IBOutlet var selectedView: AnimationView!
	@IBOutlet var dayLabel: UILabel!
	@IBOutlet weak var statusIndicator: UILabel!
	
	let textSelectedColor = UIColor.whiteColor()
	let textDeselectedColor = UIColor.blackColor()
	let previousMonthTextColor = UIColor.lightGrayColor()
	lazy var todayDate : String = {
		[weak self] in
		let aString = self!.c.stringFromDate(NSDate())
		return aString
		}()
	lazy var c : NSDateFormatter = {
		let f = NSDateFormatter()
		f.dateFormat = "yyyy-MM-dd"
		
		return f
	}()
	
	func setupCellBeforeDisplay(cellState: CellState, date: NSDate) {
		// Setup Cell text
		dayLabel.text =  cellState.text
		
		// Setup text color
		configureTextColor(cellState)
		
		// Setup Cell Background color
		self.backgroundColor = c.stringFromDate(date) == todayDate ? todayColor : normalDayColor
		
		// Setup cell selection status
		delayRunOnMainThread(0.0) {
			self.configueViewIntoBubbleView(cellState)
		}
		
		self.statusIndicator.hidden = true
//		self.statusIndicator.hidden = date.timeIntervalSinceNow > 0 ? true : false
//		self.statusIndicator.textColor = date.timeIntervalSinceNow > 0 ? UIColor.blackColor() : UIColor.cyanColor()
		
		// Configure Visibility
		configureSelectability(cellState)
	}
	
	func configureSelectability(cellState: CellState) {
		self.userInteractionEnabled = cellState.dateBelongsTo == .ThisMonth ? true : false
	}
	
	func configureTextColor(cellState: CellState) {
		if cellState.isSelected {
			dayLabel.textColor = textSelectedColor
		} else if cellState.dateBelongsTo == .ThisMonth {
			dayLabel.textColor = textDeselectedColor
		} else {
			dayLabel.textColor = previousMonthTextColor
		}
	}
	
	func cellSelectionChanged(cellState: CellState) {
		if cellState.isSelected == true {
			if selectedView.hidden == true {
				configueViewIntoBubbleView(cellState)
				selectedView.animateWithBounceEffect(withCompletionHandler: {
				})
			}
		} else {
			configueViewIntoBubbleView(cellState, animateDeselection: true)
		}
	}
	
	private func configueViewIntoBubbleView(cellState: CellState, animateDeselection: Bool = false) {
		if cellState.isSelected {
			self.selectedView.layer.cornerRadius =  self.selectedView.frame.width  / 2
			self.selectedView.hidden = false
			configureTextColor(cellState)
			
		} else {
			if animateDeselection {
				configureTextColor(cellState)
				if selectedView.hidden == false {
					selectedView.animateWithFadeEffect(withCompletionHandler: { () -> Void in
						self.selectedView.hidden = true
						self.selectedView.alpha = 1
					})
				}
			} else {
				selectedView.hidden = true
			}
		}
	}
}

class AnimationView: UIView {
	
	func animateWithFlipEffect(withCompletionHandler completionHandler:(()->Void)?) {
		AnimationClass.flipAnimation(self, completion: completionHandler)
	}
	func animateWithBounceEffect(withCompletionHandler completionHandler:(()->Void)?) {
		let viewAnimation = AnimationClass.BounceEffect()
		viewAnimation(self){ _ in
			completionHandler?()
		}
	}
	func animateWithFadeEffect(withCompletionHandler completionHandler:(()->Void)?) {
		let viewAnimation = AnimationClass.FadeOutEffect()
		viewAnimation(self) { _ in
			completionHandler?()
		}
	}
}