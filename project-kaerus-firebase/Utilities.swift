//
//  Utilities.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/21/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import Foundation
import Firebase
import FBSDKCoreKit
import FBSDKLoginKit

// sends a notification to all of partner's devices
func sendNotification(text: String) {
	if AppState.sharedInstance.f_oneSignalID.isEmpty {
		print("Partner not logged into any device")
	} else {
		for id in AppState.sharedInstance.f_oneSignalID {
			let osItem = [
				"contents": ["en": text],
				"include_player_ids": [id],
				"content_available": ["true"]
			]
			OneSignal.postNotification(osItem)
		}
	}
}

// sends a notification to a specific device
func sendNotification(text: String, id: String) {
	let item = [
		"contents": ["en": text],
		"include_player_ids": [id],
		"content_available": ["true"]
	]
	OneSignal.postNotification(item)
}