//
//  Copyright (c) 2015 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Firebase

class AppState: NSObject {
	static let sharedInstance = AppState()

	// user's info
	var signedIn = false
	var name: String!
	var photo: UIImage!
	var userID: String!
	var email: String!
	var firstName: String!
	
	var startDate: NSDate!
	var lastPaidDate: NSDate!
	
	// friend's info
	var f_firstName: String?
	var f_name: String?
	var f_firID: String?
	var f_photo: UIImage?
	var f_oneSignalID: String?
	
	// partner stuff
	var partnerStatus: Bool!
	var groupchat_id: String?
	
	// notification stuff
	var unseenMessagesCount = 0
	var numOfUnseenPartnerDeadlineChanges = 0
}

// all AppState functions
extension AppState {
	func setState(user: FIRUser?) {
		self.signedIn = true
		self.name = user?.displayName //?? user?.email
		self.userID = user?.uid
		self.email = user?.email
	}
	
	func setPartnerState(status: Bool,
	                    f_firstName: String?,
	                    f_id: String?,
	                    f_fullName: String?,
	                    f_groupchatId: String?) {
		self.partnerStatus = status
		self.f_firstName = f_firstName
		self.f_firID = f_id
		self.f_name = f_fullName
		self.groupchat_id = f_groupchatId
	}
}
