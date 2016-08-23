//
//  Utilities.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 8/21/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import Foundation

func sendNotification(text: String) {
	let osItem = [
		"contents": ["en": text],
		"include_player_ids": [AppState.sharedInstance.f_oneSignalID!],
		"content_available": ["true"]
	]
	OneSignal.postNotification(osItem)
}

func sendNotification(text: String, id: String) {
	let item = [
		"contents": ["en": text],
		"include_player_ids": [id],
		"content_available": ["true"]
	]
	OneSignal.postNotification(item)
}