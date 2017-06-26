//
//  NiaClassListViewController.swift
//  NiaNow
//
//  Created by David Brownstone on 6/4/17.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import UIKit
import Firebase
import MGSwipeTableCell

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
    
    var currentMember:Member!
    
    private let ref = Database.database().reference(withPath: "classes")
    private lazy var channelRef: DatabaseReference = Database.database().reference().child("channels")
    private var channelRefHandle: DatabaseHandle?
    let usersRef = Database.database().reference(withPath: "users")
    var user: User!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.membersEmail = self.keychain.get("email")!
        self.membersPhone = keychain.get("phone")!
        self.membersName = self.keychain.get("fullname")!
        
        self.classes = appDelegate.classes
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
    
    
    @IBAction func selectAnAction(_ sender: UISegmentedControl) {
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
            niaClass.addAMember(name: self.currentMember.name)
            let niaClassRef = self.ref.child(text.lowercased())
            niaClassRef.setValue(niaClass.toAnyObject())
            self.currentMember.classes.append(niaClass.name)
            let memberRef = self.ref.child(self.currentMember.name)
            memberRef.setValue(self.currentMember.toAnyObject())
        }
        
        alertController.addAction(saveAction)
        saveAction.isEnabled = false
        self.currentCreateAction = saveAction
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        
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

        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell") as! MGSwipeTableCell
        
        if indexPath.row == 0 {
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            cell.accessoryType = .none
            return cell
        }
        let niaClass = classes[indexPath.row - 1]
        let chatButton = MGSwipeButton(title: " Chat ", backgroundColor: UIColor.blue, callback: {
            (sender: MGSwipeTableCell!) -> Bool in
            self.performSegue(withIdentifier: "showClassChat", sender:self.classes[indexPath.row - 1])
            return false
        })
        cell.leftButtons = [chatButton]
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
                appDelegate.signOut()
            }
        }
        alertController.addAction(logoutAction)
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
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
    }
}

