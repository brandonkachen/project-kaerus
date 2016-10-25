//
//  ChatViewController.swift
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
	var numOfMessagesShown : UInt = 15 // show 15 messages initially
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// set input bar
		self.inputToolbar.contentView.leftBarButtonItem = nil
		
		// set up view controller
		self.senderId = AppState.sharedInstance.userID
		self.senderDisplayName = AppState.sharedInstance.name
		self.edgesForExtendedLayout = UIRectEdge.Top
		self.setupBubbles()
		// TODO
		//		self.collectionView.collectionViewLayout.messageBubbleFont = UIFont.init(name: "Avenir Next", size: 15)
		
		// set timestamp formatter
		detailedDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SS"
		detailedDateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
		
		avatars["PK"] = JSQMessagesAvatarImageFactory.avatarImageWithUserInitials("PK", backgroundColor: UIColor.lightGrayColor(), textColor: UIColor.whiteColor(), font: UIFont.systemFontOfSize(CGFloat(14)), diameter: UInt(collectionView.collectionViewLayout.outgoingAvatarViewSize.width))
		
		chatSetup()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.partnerInfoChanged(_:)), name: "PartnerInfoChanged_Chat", object: nil)
		self.showLoadEarlierMessagesHeader = true
	}
	
	func partnerInfoChanged(_: NSNotification) {
		chatSetup()
	}
	
	func chatSetup() {
		messages.removeAll()
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
		if let lastMessage = messages.last where AppState.sharedInstance.partnerStatus != false {
			let lastMessageTimeStamp = self.detailedDateFormatter.stringFromDate(lastMessage.date)
			self.seenRef.child(AppState.sharedInstance.userID).setValue(lastMessageTimeStamp)
		}
		let statusBarHeight = UIApplication.sharedApplication().statusBarFrame.size.height
		let rect = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.width, height: statusBarHeight)
		let statusBarView = UIView.init(frame: rect)
		statusBarView.backgroundColor = UIColor.init(red: 250/255, green: 94/255, blue: 76/255, alpha: 1)
		self.view.addSubview(statusBarView)
		
		self.collectionView.collectionViewLayout.springinessEnabled = false
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
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
		let messagesQuery = messagesRef.queryLimitedToLast(numOfMessagesShown)
		
		// checks if this function has been called again
		if _chatRefHandle != nil {
			messagesQuery.removeAllObservers()
			messages.removeAll()
			reloadMessagesView()
		}
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
				if self.tabBarController?.selectedIndex == 1 {
					self.seenRef.child(AppState.sharedInstance.userID).setValue(strDate)
				}
				FIRCrashMessage("messagesQuery: finished receiving message")
			}
		}
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, header headerView: JSQMessagesLoadEarlierHeaderView!, didTapLoadEarlierMessagesButton sender: UIButton!) {
		numOfMessagesShown += 10
		observeMessages()
		automaticallyScrollsToMostRecentMessage = false
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
		return message.senderId == senderId ? outgoingBubbleImageView : incomingBubbleImageView
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
		let message = messages[indexPath.item]
		return avatars[message.senderId]
	}
	
	override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
			as! JSQMessagesCollectionViewCell
		cell.textView.dataDetectorTypes = .None // don't want any data detection
		
		let message = messages[indexPath.item]
		// if cell belongs to sender, use white for the font color. otherwise, black
		cell.textView!.textColor = message.senderId == senderId ? UIColor.whiteColor() : UIColor.blackColor()
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
		return nil
	}
	
	override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
		let message = messages[indexPath.item]
		if message.date == lastSeen && message.senderId == AppState.sharedInstance.userID {
			return kJSQMessagesCollectionViewCellLabelHeightDefault
		}
		return 0.0
	}
	
	// MARK: - Other stuff
	
	private func setupBubbles() {
		let factory = JSQMessagesBubbleImageFactory()
		outgoingBubbleImageView = factory.outgoingMessagesBubbleImageWithColor(UIColor.init(red: 252/255, green: 92/255, blue: 68/255, alpha: 0.85))
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
