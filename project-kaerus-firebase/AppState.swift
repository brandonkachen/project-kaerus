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
	var username: String?
	var photoUrl: NSURL?
	var userID: String?
	var email: String?
	var friend_status: String?
	var groupchat_id: String?
	
	// friend's info
	var f_displayName: String?
	var f_FIRid: String?
	var f_photoURL: NSURL?

	func setState(user: FIRUser?) {
		self.signedIn = true
		self.username = user?.displayName //?? user?.email
		self.photoUrl = user?.photoURL
		self.userID = user?.uid
		self.email = user?.email
	}
}
