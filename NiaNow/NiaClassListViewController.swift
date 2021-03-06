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
    var selectedChatClass:NiaClass!
    var keychain = KeychainSwift()
    var membersName = ""
    var membersPhone = ""
    var membersEmail = ""
    
    var isEditingMode = false
    
    var currentCreateAction:UIAlertAction!
    
    var signedIn = ""
    
    var currentMember = loggedInMember
    
    private let classRef = Database.database().reference(withPath: "classes")
    private lazy var channelRef: DatabaseReference = Database.database().reference().child("channels")
    private var channelRefHandle: DatabaseHandle?
    let usersRef = Database.database().reference(withPath: "users")
    var user: User!
    
    var easyTipView:EasyTipView!
    var preferences = EasyTipView.Preferences()
    var popupVisible = false
    
    var tableViewCellRows:[CGRect]!
    
    var segment: UISegmentedControl!
    let longPressRec = UILongPressGestureRecognizer()
    let logoutPress = UILongPressGestureRecognizer()
    var logoutBtn:UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        segment = UISegmentedControl(items: [UIImage(named:"chat")!, UIImage(named:"class")!])
        segment.sizeToFit()
        segment.tintColor = UIColor.darkGray
        segment.setTitleTextAttributes([NSFontAttributeName: UIFont(name:"Futura-Medium", size: 15)!],
                                       for: UIControlState.normal)
        segment.addTarget(self, action: #selector(NiaClassListViewController.segmentAction(_:)), for: .valueChanged)
        longPressRec.addTarget(self, action: #selector(NiaClassListViewController.showPopUp(_ :)))

        segment.addGestureRecognizer(longPressRec)
        
        logoutBtn = UIButton(type: .custom)
        logoutBtn.setImage(UIImage(named: "logout"), for: .normal)
        logoutBtn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        logoutBtn.addTarget(self, action: #selector(NiaClassListViewController.logout), for: .touchUpInside)
        logoutBtn.addGestureRecognizer(logoutPress)
        logoutPress.addTarget(self, action: #selector(NiaClassListViewController.showLogoutPopUp(_ :)))

        
        let barButtonItem = UIBarButtonItem(customView:segment)
        self.navigationItem.rightBarButtonItem = barButtonItem
        let leftBarButton = UIBarButtonItem(customView: logoutBtn)
        self.navigationItem.leftBarButtonItem = leftBarButton
        
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
    
    func showLogoutPopUp(_ sender:AnyObject) {
        let msg = "Logout"
        if !popupVisible {
            preferences.drawing.backgroundColor = UIColor.white
            self.easyTipView = EasyTipView(text: msg, preferences: preferences)
            self.easyTipView.show(forItem: self.navigationItem.leftBarButtonItem!, withinSuperView: self.navigationController?.view)
            popupVisible = true
        }
    }
    
    func removePopUp(_ sender:AnyObject) {
        let touchLoc = (sender as! UITapGestureRecognizer).location(in: self.tableView)
        let index = getTheTableRow(touchLoc)
        let indexPath = NSIndexPath(row: index, section:0)
        
//        print("Y of Cell is: \(rectOfCellInSuperview.origin.y)

        if let tipView = self.easyTipView {
            tipView.dismiss(withCompletion: nil)
            popupVisible = false
        }
        segment.selectedSegmentIndex = UISegmentedControlNoSegment
//        self.tableView.selectRow(at:indexPath as IndexPath, animated:true, scrollPosition:.bottom)
        if index > -1 {
            self.performSegue(withIdentifier: "participants", sender:classes[indexPath.row] )
        }

    }
    
    func getTheTableRow(_ rect:CGPoint) -> NSInteger {
        let verticalPos = rect.y
        var theTotalHeightOfTable = 0 as CGFloat
        for aRow in tableViewCellRows {
            theTotalHeightOfTable += aRow.size.height
        }
        if verticalPos > theTotalHeightOfTable {
            return -1
        }
        if rect.y > 0 {
            for i in 0..<tableViewCellRows.count {
                let row = tableViewCellRows[i]
                let startRow = row.origin.y
                let endRow = row.origin.y + row.size.height
                if verticalPos >= startRow && verticalPos <= endRow {
                    return i - 1
                }
            }
        }
        return 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        classRef.observe(.value, with: { snapshot in
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
                selectTheClass()
            } else {
                self.performSegue(withIdentifier: "showClassChat", sender:self.classes[0])
            }
        default:
            didClickOnAddButton()
        }
    }
    
    func selectTheClass() {
        let optionMenuController = UIAlertController(title: "Chat Mode", message: "Select which class you wish to join", preferredStyle: .actionSheet)
        
        // Create UIAlertAction for UIAlertController
        
        for aClass in self.classes {
            let classTitle = aClass.name
            var addAction:UIAlertAction!
            if aClass.members.contains(loggedInMember.name) {
                addAction = UIAlertAction(title: classTitle, style: .default, handler: {
                    (alert: UIAlertAction!) -> Void in
                    print("\(classTitle) selected")
                    self.performSegue(withIdentifier: "showClassChat", sender:aClass)
                })
                optionMenuController.addAction(addAction)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (alert: UIAlertAction!) -> Void in
            print("Cancel")
        })
        optionMenuController.addAction(cancelAction)
        // Present UIAlertController with Action Sheet
        
        self.present(optionMenuController, animated: true, completion: nil)

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
            let niaClassRef = self.classRef.child(text.lowercased())
            niaClassRef.setValue(niaClass.toAnyObject())
            self.currentMember?.classes.append(niaClass.name)
            let memberRef = self.usersRef.child((self.currentMember?.name.lowercased())!)
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
        let rectOfCellInTableView = tableView.rectForRow(at: indexPath)
        if indexPath.row == 0 {
            tableViewCellRows = []
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            cell.accessoryType = .none
            tableViewCellRows.append(rectOfCellInTableView)
            return cell
        } else {
            tableViewCellRows.append(rectOfCellInTableView)

        }
        let niaClass = classes[indexPath.row - 1]
        cell.textLabel?.text = niaClass.name
        cell.detailTextLabel?.text = "Members: \(niaClass.numberOfUsers())"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if indexPath.row == 0 {
            return []
        }
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (deleteAction, indexPath) -> Void in
            let niaClass = self.classes[indexPath.row - 1]
            niaClass.ref?.removeValue()
        }
        let chatAction = UITableViewRowAction(style: .normal, title: "Chat") { (chatAction, indexPath) -> Void in
            print("Go to chat mode")
            self.performSegue(withIdentifier: "showClassChat", sender:self.classes[indexPath.row - 1])
        }
        chatAction.backgroundColor = UIColor.green
        return [deleteAction, chatAction]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row > 0 {
            self.performSegue(withIdentifier: "participants", sender:classes[indexPath.row - 1] )
        }
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
            chatViewController.niaClassRef = self.classRef.child(niaClass.name.lowercased())
        } else if segue.identifier == "participants" {
            let classViewController = segue.destination as! NiaClassViewController
            classViewController.selectedClass = sender as! NiaClass
        }
        segment.selectedSegmentIndex = UISegmentedControlNoSegment
    }
}

