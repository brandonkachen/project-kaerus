//
//  FriendData.swift
//  Pods
//
//  Created by Brandon Chen on 7/18/16.
//
//

import UIKit

struct FriendData {
	let name : String!
	let first_name : String!
	let id : String! // FIR ID, not FB ID
	let pic : UIImage!
	let picURL : NSURL!
	let partnerStatus : Bool!
	var whoAsked = ""
	
	// Initialize from arbitrary data
	init(name: String, first_name: String, id: String, picString: String, partnerStatus: Bool) {
		self.name = name
		self.first_name = first_name
		self.id = id
		
		let picURL = NSURL(string: picString)!
		self.picURL = picURL
		
		let picData = NSData(contentsOfURL: picURL)
		self.pic = UIImage(data: picData!)
		
		self.partnerStatus = partnerStatus
	}
}