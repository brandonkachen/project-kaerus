//
//  PaymentsUserInfo.swift
//  
//
//  Created by Brandon Chen on 8/3/16.
//
//

import Foundation

struct PaymentsUserInfo {
	let profilePic: NSURL!
	let name: String!
	let totalBalance: String!
	let owedBalance: String!
	
	init(pic: NSURL, username: String, total: Float, owed: Float) {
		profilePic = pic
		name = username
		totalBalance = total.description
		owedBalance = owed.description
	}
}