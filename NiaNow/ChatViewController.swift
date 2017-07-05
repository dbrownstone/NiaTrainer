//
//  ChatViewController.swift
//  NiaNow
//
//  Created by David Brownstone on 17/06/2017.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import EasyTipView
import Photos

class ChatViewController: JSQMessagesViewController {

    lazy var storageRef: StorageReference = Storage.storage().reference(forURL: "gs://nianow-a5d5b.appspot.com")
    
    var niaClassRef: DatabaseReference?
    var niaClass: NiaClass? {
        didSet {
            title = niaClass?.name
        }
    }
    
    private lazy var userIsTypingRef: DatabaseReference =
        self.niaClassRef!.child("typingIndicator").child(self.senderId)
    private var localTyping = false
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    private lazy var usersTypingQuery: DatabaseQuery =
        self.niaClassRef!.child("typingIndicator").queryOrderedByValue().queryEqual(toValue: true)
    
    var messages = [JSQMessage]()
    private lazy var messageRef: DatabaseReference = self.niaClassRef!.child("messages")
    let ref = Database.database().reference(withPath: "users")
    private var newMessageRefHandle: DatabaseHandle?
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    var currentUser = Auth.auth().currentUser
    
    @IBOutlet weak var activeMembersView: UIToolbar!
    var easyTipView:EasyTipView!
    var popupVisible = false
    
    var currentActiveMembers = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.senderId = currentUser?.uid
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
//        collectionView?.collectionViewLayout.incomingAvatarViewSize = CGSize(width: kJSQMessagesCollectionViewAvatarSizeDefault, height:kJSQMessagesCollectionViewAvatarSizeDefault )
//        collectionView?.collectionViewLayout.outgoingAvatarViewSize = CGSize(width: kJSQMessagesCollectionViewAvatarSizeDefault, height:kJSQMessagesCollectionViewAvatarSizeDefault )
        observeMessages()
        self.inputToolbar.contentView.rightBarButtonItem = JSQMessagesToolbarButtonFactory.defaultSendButtonItem()
        
        collectionView?.collectionViewLayout.springinessEnabled = false
        
        automaticallyScrollsToMostRecentMessage = true
        self.collectionView?.reloadData()
        self.collectionView?.layoutIfNeeded()
        
        let touch = UITapGestureRecognizer(target:self, action:#selector(ChatViewController.removePopUp(_:)))
        self.view.addGestureRecognizer(touch)
        
        Messaging.messaging().subscribe(toTopic: title!);
    }

    @IBAction func showPopup(_ sender: Any) {
        var preferences = EasyTipView.globalPreferences
        preferences.drawing.arrowPosition = EasyTipView.ArrowPosition.top

        var text = ""
        for i in 0..<currentActiveMembers.count {
            switch i {
            case 0:
                text = currentActiveMembers[i]
            default:
                text = "\(text),\n\(currentActiveMembers[i])"
            }
        }

        self.easyTipView = EasyTipView(text: text, preferences: preferences)
        self.easyTipView.show(forItem: sender as! UIBarItem, withinSuperView: self.navigationController?.view)
        popupVisible = true
    }
    
    func removePopUp(_ sender:AnyObject) {
        if let tipView = self.easyTipView {
            tipView.dismiss(withCompletion: nil)
            popupVisible = false
        }
    }
    
    func addCurrentActiveUsers() {
        ref.observe(.value, with: { snapshot in
            for aUser in snapshot.children {
                let member = Member(snapshot: aUser as! DataSnapshot)
                if member.authenticated && member.classes.contains(self.title!) ||
                    member.name == self.niaClass?.originatorFullname {
                    self.currentActiveMembers.append(member.name)
                }
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        self.topContentAdditionalInset = 50
        addCurrentActiveUsers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observeTyping()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        removePopUp(self)
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        
        if message.senderId == senderId {
            cell.textView?.textColor = UIColor.white
        } else {
            cell.textView?.textColor = UIColor.black
        }
        return cell
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString!
    {
        return messages[indexPath.item].senderId == senderId ? nil : NSAttributedString(string: messages[indexPath.item].senderDisplayName)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat
    {
        return messages[indexPath.item].senderId == senderId ? 0 : 15
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        var backgroundColor:UIColor!
        var textColor:UIColor!
        let message = messages[indexPath.item]
        let initials = message.senderDisplayName.components(separatedBy:" ").reduce(""){ ($0 == "" ? "" : "\($0.characters.first!)") + "\($1.characters.first!)" }
        if message.senderDisplayName == self.currentUser?.displayName {
            backgroundColor = UIColor.jsq_messageBubbleBlue()
            textColor = UIColor.white
        } else {
            backgroundColor = UIColor.jsq_messageBubbleLightGray()
            textColor = UIColor.black
        }
        return nil
        //return getAvatar(initials: initials.lowercased(), background: backgroundColor, text: textColor)
    }
    
    func getAvatar(initials:String, background: UIColor, text: UIColor) -> JSQMessagesAvatarImage{
        return JSQMessagesAvatarImageFactory.avatarImage(withUserInitials: initials, backgroundColor: background, textColor: text, font: UIFont.systemFont(ofSize: 6), diameter: 10)
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        let itemRef = messageRef.childByAutoId()
        let messageItem = [ // 2
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": text!,
            ]
        
        itemRef.setValue(messageItem)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        finishSendingMessage()
        
        isTyping = false
    }
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }

    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            messages.append(message)
//            Messaging.messaging().sendMessage(["DavidMsg" : message], to: String, withMessageID: String, timeToLive: 30)
        }
    }
    
    private func observeMessages() {
        messageRef = niaClassRef!.child("messages")
        let messageQuery = messageRef.queryLimited(toLast:25)
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            let messageData = snapshot.value as! Dictionary<String, String>
            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!, let text = messageData["text"] as String!, text.characters.count > 0 {
                self.addMessage(withId: id, name: name, text: text)
                self.finishReceivingMessage()
            } else {
                print("error! Could not decode message data")
            }
        })
    }
    
    private func observeTyping() {
        let typingIndicatorRef = niaClassRef!.child("typingIndicator")
        userIsTypingRef = typingIndicatorRef.child(senderId)
        userIsTypingRef.onDisconnectRemoveValue()
        usersTypingQuery.observe(.value) { (data: DataSnapshot) in
            if data.childrenCount == 1 && self.isTyping {
                return
            }
            
            self.showTypingIndicator = data.childrenCount > 0
            self.scrollToBottom(animated: true)
        }
    }
    
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        // If the text is not empty, the user is typing
        isTyping = textView.text != ""
    }
}
