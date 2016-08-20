//
//  NSDateExtension.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/19/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import Foundation

extension NSDate {
	func daySuffix() -> String {
		let calendar = NSCalendar.currentCalendar()
		let dayOfMonth = calendar.component(.Day, fromDate: self)
		switch dayOfMonth {
		case 1, 21, 31: return "st"
		case 2, 22: return "nd"
		case 3, 23: return "rd"
		default: return "th"
		}
	}
}