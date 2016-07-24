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
	var avatars = Dictionary<String, UIImage>()
	var messageRef, userIsTypingRef: FIRDatabaseReference!
//	private var localTyping = false
		
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// No avatars
		collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSizeZero
		collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero
		
		// set up view controller
		self.senderId = AppState.sharedInstance.userID
		self.senderDisplayName = AppState.sharedInstance.username
		self.title = "Messages"
		self.edgesForExtendedLayout = UIRectEdge.None
		self.setupBubbles()
		
		print("AppState.sharedInstance.groupchat_id is: ", AppState.sharedInstance.groupchat_id)
		
		// set up Firebase branch where messages will be stored
		if let chat_id = AppState.sharedInstance.groupchat_id {
			messageRef = FIRDatabase.database().reference().child("Messages/\(chat_id)")
			// get latest messages
			observeMessages()
		} else { // user doesn't have a partner; show "get partner" screen
//			noPartnerScreen.hidden = false
//			noPartnerScreen.alpha = 1
		}
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		
		// see if partner is typing
//		observeTyping()
	}
	
	
	// MARK: - messaging
	
	func addMessage(id: String, name: String, content: String) {
		let message = JSQMessage(senderId: id, displayName: name, text: content)
		messages.append(message)
	}
	
	private func observeMessages() {
		let messagesQuery = messageRef.queryLimitedToLast(25)
		messagesQuery.observeEventType(.ChildAdded) { (snapshot: FIRDataSnapshot!) in
			
			// get the info from snapshot
			let id = snapshot.childSnapshotForPath("id").value as! String
			let displayName = snapshot.childSnapshotForPath("displayName").value as! String
			let text = snapshot.childSnapshotForPath("text").value as! String
			
			// add to local messages array
			self.addMessage(id, name: displayName, content: text)
			self.finishReceivingMessage()
		}
	}
	
	override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!,
	                                 senderDisplayName: String!, date: NSDate!) {
		// get timestamp to order things in Firebase
		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss:SS"
		dateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
		
		// add sender's ID so if users send messages at the exact same time (however unlikely), they won't erase one another
		let timestamp = dateFormatter.stringFromDate(NSDate()) + "<" + self.senderId + ">"
		
		// create the new entry
		let itemRef = messageRef.child(timestamp)
		let messageItem = [
			"id" : senderId,
			"displayName" : senderDisplayName,
			"text" : text
		]
		itemRef.setValue(messageItem)
		
		// finishing touches
		JSQSystemSoundPlayer.jsq_playMessageSentSound()
		finishSendingMessage()
//		isTyping = false
	}
	
	
//	// MARK: - check if user is typing
//	
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
//		let typingIndicatorRef = FIRDatabase.database().reference().child("typingIndicator")
//		userIsTypingRef = typingIndicatorRef.child(senderId)
//		userIsTypingRef.onDisconnectRemoveValue()
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
		return nil
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