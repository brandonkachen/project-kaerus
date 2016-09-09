//
//  SecondViewController.swift
//  project-kaerus-firebase
//
//  Created by Brandon Chen on 7/15/16.
//  Copyright © 2016 Brandon Chen. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
	var outgoingBubbleImageView, incomingBubbleImageView: JSQMessagesBubbleImage!
	var messages = [JSQMessage]()
	var avatars = Dictionary<String, JSQMessagesAvatarImage>()
	var messagesRef, userIsTypingRef, seenRef: FIRDatabaseReference!
	let detailedDateFormatter = NSDateFormatter() // for timestamp
//	var usersTypingQuery: FIRDatabaseQuery!

//	private var localTyping = false
	private var lastSeen: NSDate = NSDate.distantPast()
	private var _chatRefHandle, _seenRefHandle: FIRDatabaseHandle!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// set input bar
		self.inputToolbar.contentView.leftBarButtonItem = nil
		
		// set up view controller
		self.senderId = AppState.sharedInstance.userID
		self.senderDisplayName = AppState.sharedInstance.name
		self.edgesForExtendedLayout = UIRectEdge.None
		self.setupBubbles()
		self.collectionView.collectionViewLayout.springinessEnabled = false
		
		// set timestamp formatter
		detailedDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SS"
		detailedDateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")

		avatars["PK"] = JSQMessagesAvatarImageFactory.avatarImageWithUserInitials("PK", backgroundColor: UIColor.lightGrayColor(), textColor: UIColor.whiteColor(), font: UIFont.systemFontOfSize(CGFloat(14)), diameter: UInt(collectionView.collectionViewLayout.outgoingAvatarViewSize.width))
		
		chatSetup()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.partnerInfoChanged(_:)), name: "PartnerInfoChanged_Chat", object: nil)
	}
	
	func partnerInfoChanged(_: NSNotification) {
		messages.removeAll()
		chatSetup()
	}
	
	func chatSetup() {
		// set up Firebase branch where messages will be stored)
		if let chat_id = AppState.sharedInstance.groupchat_id where chat_id != "" {
			// add user and partner icons
			avatars[senderId] = JSQMessagesAvatarImage.avatarWithImage(AppState.sharedInstance.photo)
			avatars[AppState.sharedInstance.f_firID!] = JSQMessagesAvatarImage.avatarWithImage(AppState.sharedInstance.f_photo)
			
			// set refs
			let ref = FIRDatabase.database().reference().child("Chat").child(chat_id)
			seenRef = ref.child("Seen")
			messagesRef = ref.child("Messages")
			observeMessages() // cannot be in viewWill/DidAppear because it will duplicate messages!
			observePartnerSeen()
			self.inputToolbar.hidden = false
		} else { // user doesn't have a partner
			let sys_message = JSQMessage(senderId: "PK", displayName: "PK", text: "Looks like you don't have a friend working with you  :(\n\nPlease ask them to install this app, then add them in the 'Settings' pane!")
			messages.append(sys_message)
			removeRefObservers()
			seenRef = nil
			messagesRef = nil
			self.inputToolbar.hidden = true
		}
		self.reloadMessagesView()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.tabBarController?.tabBar.items![1].badgeValue = nil
		AppState.sharedInstance.unseenMessagesCount = 0
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
//		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	func removeRefObservers() {
		if messagesRef != nil {
			messagesRef.removeObserverWithHandle(_chatRefHandle)
		}
		if seenRef != nil {
			seenRef.removeObserverWithHandle(_seenRefHandle)
		}
	}
	
	deinit {
		removeRefObservers()
	}
	
	// MARK: - messaging
	
	func addMessage(id: String, name: String, date: NSDate,content: String) {
		let message = JSQMessage(senderId: id, senderDisplayName: name, date: date, text: content)
		messages.append(message)
	}
	
	private func observeMessages() {
		let messagesQuery = messagesRef.queryLimitedToLast(10)
		_chatRefHandle = messagesQuery.observeEventType(.ChildAdded) { (snapshot: FIRDataSnapshot!) in
			if snapshot.exists() {
				let id = snapshot.childSnapshotForPath("id").value as! String
				let displayName = snapshot.childSnapshotForPath("displayName").value as! String
				let text = snapshot.childSnapshotForPath("text").value as! String
				let strDate = snapshot.childSnapshotForPath("date").value as! String
				let date = self.detailedDateFormatter.dateFromString(strDate)!
				
				// add to local messages array
				self.addMessage(id, name: displayName, date: date,content: text)
				
				self.finishReceivingMessage()
				
				// set seen to this message
				self.seenRef.child(AppState.sharedInstance.userID).setValue(strDate)
				FIRCrashMessage("messagesQuery: finished receiving message")
			}
		}
	}
	
	override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!,
	                                 senderDisplayName: String!, date: NSDate!) {
		// create the new entry
		let itemRef = messagesRef.childByAutoId()
		let messageItem = [
			"id" : senderId,
			"displayName" : senderDisplayName,
			"text" : text,
			"date" : detailedDateFormatter.stringFromDate(date)
		]
		itemRef.setValue(messageItem)

		// finishing touches
		finishSendingMessage()

		// send a notification to partner
		sendNotification(AppState.sharedInstance.firstName + ": " + text)
		
		FIRCrashMessage("didPressSendButton: finished sending message")
//		isTyping = false
	}
	
	
	// MARK: - check if partner has seen messages yet
	
	func observePartnerSeen() {
		_seenRefHandle = seenRef.child(AppState.sharedInstance.f_firID!).observeEventType(.Value) { (snapshot: FIRDataSnapshot!) in
			if let strDate = snapshot.value as? String {
				FIRCrashMessage("seenRef: strDate valid")
				self.lastSeen = self.detailedDateFormatter.dateFromString(strDate)!
				self.reloadMessagesView()
			}
			FIRCrashMessage("seenRef: updated")
		}
	}

	
	// MARK: - check if user is typing
	
//	var isTyping: Bool {
//		get {
//			return localTyping
//		} set {
//			localTyping = newValue
//			userIsTypingRef.setValue(newValue)
//		}
//	}
//
//	private func observeTyping() {
//		let typingIndicatorRef = FIRDatabase.database().reference().child("Chat").child(AppState.sharedInstance.groupchat_id!).child("typingIndicator")
//		userIsTypingRef = typingIndicatorRef.child(senderId)
//		userIsTypingRef.onDisconnectRemoveValue()
//		
//		usersTypingQuery = typingIndicatorRef.queryOrderedByValue().queryEqualToValue(true)
//		
//		usersTypingQuery.observeEventType(.Value) { (data: FIRDataSnapshot!) in
//			if data.childrenCount == 1 && self.isTyping { // You're the only typing, don't show the indicator
//				return
//			}
//			self.showTypingIndicator = data.childrenCount > 0
//			self.scrollToBottomAnimated(true)
//		}
//	}
//	
//	override func textViewDidChange(textView: UITextView) {
//		super.textViewDidChange(textView)
//		
//		// If the text is not empty, the user is typing
//		isTyping = textView.text != ""
//	}
	
	
	// MARK: - Collections
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
		return messages[indexPath.item]
	}
	
	override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return messages.count
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
		let message = messages[indexPath.item]
		if message.senderId == senderId { 
			return outgoingBubbleImageView
		} else {
			return incomingBubbleImageView
		}
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
		let message = messages[indexPath.item]
		return avatars[message.senderId]
	}
	
	override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
	  let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
		as! JSQMessagesCollectionViewCell
			
	  let message = messages[indexPath.item]
			
	  if message.senderId == senderId {
		cell.textView!.textColor = UIColor.whiteColor()
      } else {
		cell.textView!.textColor = UIColor.blackColor()
	  }
	  return cell
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
		let message = messages[indexPath.item]
		
		if indexPath.item == 0 {
			return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(message.date)
		}
		
		if indexPath.item > 1 {
			let previousMessage = self.messages[indexPath.item - 1] // get the message before this one
			
			if (message.date.timeIntervalSinceDate(previousMessage.date)/60) > 30 {
				return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(message.date)
			}
		}
		return nil
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
		if indexPath.item == 0 {
			return kJSQMessagesCollectionViewCellLabelHeightDefault
		}
		
		if indexPath.item > 1 {
			let message = messages[indexPath.item]
			let previousMessage = messages[indexPath.item - 1]
			
			if message.date.timeIntervalSinceDate(previousMessage.date)/60 > 30 {
				return kJSQMessagesCollectionViewCellLabelHeightDefault
			}
		}
		return 0
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, didTapAvatarImageView avatarImageView: UIImageView!, atIndexPath indexPath: NSIndexPath!) {
		print("tapped avatar image")
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
		let message = messages[indexPath.item]
		if message.date == lastSeen && message.senderId == AppState.sharedInstance.userID {
			return NSAttributedString(string: "seen ✓")
		}
		if indexPath.item == messages.count-1 && message.senderId == AppState.sharedInstance.userID {
			return NSAttributedString(string: "delivered")
		}
		return nil
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
		let message = messages[indexPath.item]
		if message.date == lastSeen && message.senderId == AppState.sharedInstance.userID {
			return kJSQMessagesCollectionViewCellLabelHeightDefault
		}
		if indexPath.item == messages.count-1 && message.senderId == AppState.sharedInstance.userID {
			return kJSQMessagesCollectionViewCellLabelHeightDefault
		}
		return 0.0
	}
	
	// MARK: - Other stuff
	
	private func setupBubbles() {
	  let factory = JSQMessagesBubbleImageFactory()
	  outgoingBubbleImageView = factory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor())
	  incomingBubbleImageView = factory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func reloadMessagesView() {
		self.collectionView?.reloadData()
	}
}