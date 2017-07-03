//
//  NiaClassListViewController.swift
//  NiaNow
//
//  Created by David Brownstone on 6/4/17.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import UIKit
import Foundation
import Firebase
import EasyTipView

class NiaClassListViewController: UITableViewController {
    
    // MARK: Constants
    let listToUsers = "ListToUsers"
    
    // MARK: Properties
    var classes:[NiaClass] = []
    var keychain = KeychainSwift()
    var membersName = ""
    var membersPhone = ""
    var membersEmail = ""
    
    var isEditingMode = false
    
    var currentCreateAction:UIAlertAction!
    
    var signedIn = ""
    
    var currentMember = loggedInMember
    
    private let ref = Database.database().reference(withPath: "classes")
    private lazy var channelRef: DatabaseReference = Database.database().reference().child("channels")
    private var channelRefHandle: DatabaseHandle?
    let usersRef = Database.database().reference(withPath: "users")
    var user: User!
    
    var easyTipView:EasyTipView!
    var preferences = EasyTipView.Preferences()
    var popupVisible = false
    
    @IBOutlet weak var logoutBtn: UIBarButtonItem!
    var segment: UISegmentedControl!
    let longPressRec = UILongPressGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        segment = UISegmentedControl(items: [UIImage(named:"chat")!, "Add Class"])
        segment.sizeToFit()
        segment.tintColor = UIColor.darkGray
        segment.setTitleTextAttributes([NSFontAttributeName: UIFont(name:"Futura-Medium", size: 15)!],
                                       for: UIControlState.normal)
        segment.addTarget(self, action: #selector(NiaClassListViewController.segmentAction(_:)), for: .valueChanged)
        longPressRec.addTarget(self, action: #selector(NiaClassListViewController.showPopUp(_ :)))

        segment.addGestureRecognizer(longPressRec)
//        logoutBtn.addGestureRecognizer(longPressRec)
        let barButtonItem = UIBarButtonItem(customView:segment)
        self.navigationItem.rightBarButtonItem = barButtonItem
        
        self.membersEmail = self.keychain.get("email")!
        self.membersPhone = keychain.get("phone")!
        self.membersName = self.keychain.get("fullname")!
        
        self.classes = appDelegate.classes
        
        preferences.drawing.font = UIFont(name: "Futura-Medium", size: 15)!
        preferences.drawing.backgroundColor = UIColor(hue:0.58, saturation:0.1, brightness:1, alpha:1)
        preferences.drawing.foregroundColor = UIColor.darkGray
        preferences.drawing.textAlignment = NSTextAlignment.center
        preferences.drawing.borderColor = UIColor.black
        preferences.drawing.borderWidth = 2
        EasyTipView.globalPreferences = preferences

        let touch = UITapGestureRecognizer(target:self, action:#selector(NiaClassListViewController.removePopUp(_:)))
        self.view.addGestureRecognizer(touch)
    }
    
    func showPopUp(_ sender:AnyObject) {
        var msg = ""
        let touchLoc = (sender as! UILongPressGestureRecognizer).location(in: self.segment)
        let segmentWidth = segment.frame.size.width
        let chatBtnOrigin = segment.frame.origin.x
        let classBtnOrigin = chatBtnOrigin + (segmentWidth / 2)
        if (touchLoc.x + chatBtnOrigin) < classBtnOrigin {
            //chat
            msg = "Chat with other members of the selected class"
            //preferences.drawing.arrowPosition = EasyTipView.ArrowPosition.bottom
        } else {
            //add class
            msg = "Add a new class"
            //preferences.drawing.arrowPosition = EasyTipView.ArrowPosition.left
        }
        if !popupVisible {
            preferences.drawing.backgroundColor = UIColor.white
            self.easyTipView = EasyTipView(text: msg, preferences: preferences)
            self.easyTipView.show(forItem: self.navigationItem.rightBarButtonItem!, withinSuperView: self.navigationController?.view)
            popupVisible = true
        }
    }
    
    func removePopUp(_ sender:AnyObject) {
        if let tipView = self.easyTipView {
            tipView.dismiss(withCompletion: nil)
            popupVisible = false
        }
        segment.selectedSegmentIndex = UISegmentedControlNoSegment
    }
    
    override func viewWillAppear(_ animated: Bool) {
        ref.observe(.value, with: { snapshot in
            var newClasses: [NiaClass] = []
            for aClass in snapshot.children {
                let niaClass = NiaClass(snapshot: aClass as! DataSnapshot)
                if niaClass.addedByUser == self.membersEmail {
                    self.membersName = niaClass.originatorFullname
                    self.keychain.set(self.membersName, forKey: "fullname")
                    newClasses.append(niaClass)
                } else if self.membersName.characters.count > 0 &&
                    niaClass.members.contains(self.membersName) {
                    newClasses.append(niaClass)
                    if loggedInMember.classes[0] == "" {
                        loggedInMember.classes = []
                    }
                    loggedInMember.classes.append(niaClass.name)
                }
            }
            self.classes = newClasses
            
            self.tableView.reloadData()
        })
        usersRef.observe(.value, with: { snapshot in
            for aUser in snapshot.children {
                var member = Member(snapshot: aUser as! DataSnapshot)
                if member.name == self.membersName {
                    self.currentMember = member
                    if !member.authenticated {
                        member.authenticated = true
                        
                        let memberRef = self.usersRef.child((self.membersName.lowercased()))
                        memberRef.setValue(member.toAnyObject())
                    }
                    break
                }
            }
        })
    }
    
        // MARK: - User Actions -
    
    
    func segmentAction(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            if self.classes.count > 1 {
            } else {
                self.performSegue(withIdentifier: "showClassChat", sender:self.classes[0])            }
        default:
            didClickOnAddButton()
        }
    }
    
    @IBAction func didClickOnEditButton(_ sender: UIBarButtonItem) {
        isEditingMode = !isEditingMode
        self.tableView.setEditing(isEditingMode, animated: true)
    }
    
    func didClickOnAddButton() {
        displayAlertToAddClass()
    }
    
    //Enable the create action of the alert only if textfield text is not empty
    func listNameFieldDidChange(_ textField:UITextField){
        self.currentCreateAction.isEnabled = (textField.text?.characters.count)! > 0
    }
    
    func displayAlertToAddClass(){
        
        let title = "New Nia Class"
        let doneTitle = "Save"
        
        let alertController = UIAlertController(title: title, message: "Enter the name of this Nia Class.", preferredStyle: UIAlertControllerStyle.alert)
        let saveAction = UIAlertAction(title: doneTitle, style: UIAlertActionStyle.default) { (action) -> Void in
            guard let textField = alertController.textFields?.first, let text = textField.text else { return }
            var niaClass = NiaClass(name: textField.text!,
                                          addedByUser: self.membersEmail,
                                          originator: self.membersName)
            niaClass.addAMember(name: (self.currentMember?.name)!)
            let niaClassRef = self.ref.child(text.lowercased())
            niaClassRef.setValue(niaClass.toAnyObject())
            self.currentMember?.classes.append(niaClass.name)
            let memberRef = self.ref.child((self.currentMember?.name)!)
            memberRef.setValue(self.currentMember?.toAnyObject())
            self.segment.selectedSegmentIndex = UISegmentedControlNoSegment
        }
        
        alertController.addAction(saveAction)
        saveAction.isEnabled = false
        self.currentCreateAction = saveAction
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            self.segment.selectedSegmentIndex = UISegmentedControlNoSegment
        })
        
        alertController.addTextField { (textField) -> Void in
            textField.placeholder = "Nia Class Name"
            textField.addTarget(self, action: #selector(NiaClassListViewController.listNameFieldDidChange(_:)), for: UIControlEvents.editingChanged)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource -
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return classes.count + 1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 24
        }
        return 44
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{

        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell")!
        
        if indexPath.row == 0 {
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            cell.accessoryType = .none
            return cell
        }
        let niaClass = classes[indexPath.row - 1]
        cell.textLabel?.text = niaClass.name
        cell.detailTextLabel?.text = "Members: \(niaClass.numberOfUsers())"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (deleteAction, indexPath) -> Void in
            let niaClass = self.classes[indexPath.row - 1]
            niaClass.ref?.removeValue()
        }
        return [deleteAction]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "participants", sender:classes[indexPath.row - 1] )
    }
    
    // MARK: - Navigation
    
    @IBAction func logout(_ sender: Any) {
        let alertController = UIAlertController(title: "Are You Sure?", message: "Do you really want to log yourself out?", preferredStyle: UIAlertControllerStyle.alert)
        let logoutAction = UIAlertAction(title: "Log me out", style: UIAlertActionStyle.default) { (action) -> Void in
            if Auth.auth().currentUser != nil {
                // User is signed in.
                do {
                    try Auth.auth().signOut()
                    self.changeMemberAuthentication(newLoginStatus:false)
                }
                catch let error as NSError {
                    print(error.localizedDescription)                    
                }
            }
            
        }
        alertController.addAction(logoutAction)
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func changeMemberAuthentication(newLoginStatus:Bool) {
        loggedInMember.authenticated = false
        let ref = Database.database().reference(withPath: "users")
        let memberRef = ref.child((loggedInMember.name.lowercased()))
        memberRef.setValue(loggedInMember.toAnyObject())
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = loggedInMember.name
        
        // Commit profile changes to server
        changeRequest?.commitChanges() { (error) in
            
            if let error = error {
                print(error.localizedDescription)
                return
            } else {
            }
        }
        self.performSegue(withIdentifier: "unwindToVC1", sender:self as NiaClassListViewController)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showClassChat" {
            let niaClass = sender as! NiaClass
            let chatViewController = segue.destination as! ChatViewController
            chatViewController.senderDisplayName = self.membersName
            chatViewController.niaClass = niaClass
            chatViewController.niaClassRef = self.ref.child(niaClass.name.lowercased())
        } else if segue.identifier == "participants" {
            let classViewController = segue.destination as! NiaClassViewController
            classViewController.selectedClass = sender as! NiaClass
        }
        segment.selectedSegmentIndex = UISegmentedControlNoSegment
    }
}

