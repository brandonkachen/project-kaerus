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
//	let incomingBubble = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImageWithColor(UIColor.lightGrayColor())
//	let outgoingBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImageWithColor(UIColor(red: 10/255, green: 180/255, blue: 230/255, alpha: 1.0))
	var outgoingBubbleImageView: JSQMessagesBubbleImage!
	var incomingBubbleImageView: JSQMessagesBubbleImage!
	var messages = [JSQMessage]()
	var avatars = Dictionary<String, UIImage>()
	var messageRef: FIRDatabaseReference!
	var userIsTypingRef: FIRDatabaseReference!
	private var localTyping = false
	
	override func viewWillAppear(animated: Bool) {
		self.senderId = AppState.sharedInstance.userID
		self.senderDisplayName = AppState.sharedInstance.displayName
		self.title = "Messages"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.edgesForExtendedLayout = UIRectEdge.None
		self.setupBubbles()
		messages.removeAll()
		// No avatars
		collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSizeZero
		collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero
		
		messageRef = FIRDatabase.database().reference().child("messages")
		observeMessages()
	}
	
	override func viewDidAppear(animated: Bool) {
	  super.viewDidAppear(animated)
	  observeMessages()
	  observeTyping()
	}
	
	override func textViewDidChange(textView: UITextView) {
	  super.textViewDidChange(textView)
		
	  // If the text is not empty, the user is typing
	  isTyping = textView.text != ""
	}
	
	override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!,
	                                 senderDisplayName: String!, date: NSDate!) {
		let itemRef = messageRef.childByAutoId()
		let messageItem = [ 
			"id": senderId,
			"displayName": senderDisplayName,
			"text": text
			]
		itemRef.setValue(messageItem)
		JSQSystemSoundPlayer.jsq_playMessageSentSound()
		finishSendingMessage()
		isTyping = false
	}
	
	
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

	
	// MARK: - messaging
	func addMessage(id: String, text: String) {
	  let message = JSQMessage(senderId: id, displayName: "", text: text)
	  messages.append(message)
	}
	
	private func observeMessages() {
		let messagesQuery = messageRef.queryLimitedToLast(25)
		messagesQuery.observeEventType(.ChildAdded) { (snapshot: FIRDataSnapshot!) in
		
		let item : Dictionary<String, AnyObject?> = [
			"id" : snapshot.childSnapshotForPath("id").value as! String,
			"displayName": snapshot.childSnapshotForPath("displayName").value as! String,
			"text" : snapshot.childSnapshotForPath("text").value as! String
		]
		
		let id = item["id"] as! String
		let text = item["text"] as! String
		self.addMessage(id, text: text)
		self.finishReceivingMessage()
		}
	}
	
	//MARK: - check if user is typing
	var isTyping: Bool {
		get {
			return localTyping
		}
		set {
			localTyping = newValue
			userIsTypingRef.setValue(newValue)
		}
	}

	private func observeTyping() {
		let typingIndicatorRef = FIRDatabase.database().reference().child("typingIndicator")
		userIsTypingRef = typingIndicatorRef.child(senderId)
		userIsTypingRef.onDisconnectRemoveValue()
	}
}