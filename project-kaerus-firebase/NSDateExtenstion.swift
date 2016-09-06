//
//  NSDateExtenstion.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 9/5/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import Foundation

extension NSDate {
	func nextDay() -> NSDate {
		return NSCalendar.currentCalendar().dateByAddingUnit(.Day, value: 1, toDate: self, options: [])!
	}
}