/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import Foundation
import Firebase

struct Goal {
  
	let key: String!
	let text: String!
	let timeDue: String!
	let ref: FIRDatabaseReference!
	var complete: Bool!
	
	// Initialize from arbitrary data
	init(text: String, timeDue: String, complete: Bool, key: String = "") {
		self.key = key
		self.text = text
		self.timeDue = timeDue
		self.complete = complete
		self.ref = nil
	}
	
	init(snapshot: FIRDataSnapshot) {
		key = snapshot.key
		let item : Dictionary<String, AnyObject?> = [
			"text" : snapshot.childSnapshotForPath("text").value as! String,
			"timeDue" : snapshot.childSnapshotForPath("timeDue").value as! String,
			"complete" : snapshot.childSnapshotForPath("complete").value as! Bool
			]

		text = item["text"] as! String
		timeDue = item["timeDue"] as! String
		complete = item["complete"] as! Bool
			
		ref = snapshot.ref
	}
	
	func toAnyObject() -> AnyObject {
		return [
		  "text": text,
		  "timeDue": timeDue,
		  "complete": complete
		]
	}
}