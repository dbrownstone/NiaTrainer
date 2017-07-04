//
//  NiaClassViewController.swift
//  NiaNow
//
//  Created by David Brownstone on 6/5/17.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import Foundation
import UIKit
import Firebase

// the\is view controller shows information about all the participants in the selected class
class NiaClassViewController: UITableViewController {
    
    var selectedClass : NiaClass!
    var members = [User]()
    var keychain = KeychainSwift()
    var user:User!
    
    var currentCreateAction:UIAlertAction!
    
    var isEditingMode = false
    
    let ref = Database.database().reference(withPath: "users")
    var currentUsers: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref.observe(.value, with: { snapshot in
            var newMembersList:[User] = []
            for aUser in snapshot.children {
                let member = Member(snapshot: aUser as! DataSnapshot)
                let name = member.name
                let email = member.email
                let phone = member.phoneNo
                let uid = member.uid
                let classes = member.classes
                let authenticated = member.authenticated
                if member.name == self.selectedClass.originatorFullname {
                    let attendee = User(uid: uid, email: email, fullname: name, phone: phone, authenticated: authenticated)
                    newMembersList.insert(attendee,at: 0)
                } else {
                    for niaClass in classes! {
                        if niaClass == self.selectedClass.name {
                            let attendee = User(uid: uid, email: email, fullname: name, phone: phone, authenticated: authenticated)
                            newMembersList.append(attendee)
                        }
                    }
                }
            }
            self.members = newMembersList
            self.tableView.reloadData()
        })
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = self.selectedClass.name
        if self.selectedClass.originatorFullname != loggedInMember.name {
            self.navigationItem.rightBarButtonItem = nil
        }
    }
    
    // MARK: - User Actions -
    
    @IBAction func didClickOnAddMemberToClass(_ sender: AnyObject) {
        displayAlertToAddMember()
    }
    

    
    // MARK: - UITableViewDataSource -
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return members.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        
        if indexPath.row == 0 {
            var online = ""
            if members[indexPath.row].fullname == self.selectedClass.originatorFullname &&
                members[indexPath.row].authenticated {
                online = "*"
            }
            cell?.textLabel?.text = "\(self.selectedClass.originatorFullname)\(online)"
            cell?.detailTextLabel?.text = ""
        } else {
            if (members[indexPath.row].authenticated) {
                cell?.textLabel?.text = "\(members[indexPath.row].fullname)*"
            } else {
                cell?.textLabel?.text = members[indexPath.row].fullname
            }
            cell?.detailTextLabel?.text = members[indexPath.row].phoneNumber

        }
        return cell!
    }
    
    
    func displayAlertToAddMember(){
        
        let title = "New Member"
        let doneTitle = "Add"
        
        let alertController = UIAlertController(title: title, message: "Write the name of your new member.", preferredStyle: UIAlertControllerStyle.alert)
        let createAction = UIAlertAction(title: doneTitle, style: UIAlertActionStyle.default) { (action) -> Void in
            
            let memberName = alertController.textFields?.first?.text?.capitalized
            let memberEmail = alertController.textFields?[1].text
            let memberPhone = alertController.textFields?[2].text
//            let memberParticipatingClassName = self.selectedClass.name
            Auth.auth().createUser(withEmail: memberEmail!, password: "1A2B3C") { user, error in
                if error == nil {
                    print(memberName ?? "")
                    //first make sure that both entries have been filled
                    guard let emailTextField = alertController.textFields?.first, let _ = emailTextField.text else { return }
                    guard let nameTextField = alertController.textFields?[1],  let _ = nameTextField.text else { return }
                    
                    let member = Member(email: memberEmail!,  name: memberName!, phone: memberPhone!, uid: (user?.uid)!, niaClass: self.selectedClass.name)    //UUID().uuidString)
                    let memberRef = self.ref.child((memberName?.lowercased())!)
                    memberRef.setValue(member.toAnyObject())
                    
                    if  self.selectedClass.members.first == "dummy" {
                        self.selectedClass.members = []
                    }
                    self.selectedClass.addAMember(name: memberName!)
                    
                    let aRef = Database.database().reference(withPath: "classes")
                    let classRef = aRef.child(self.selectedClass.name.lowercased())
                    classRef.setValue(self.selectedClass.toAnyObject())
                    self.tableView.reloadData()
                } else {
                    let errorAlertController = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                    errorAlertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
                    self.present(errorAlertController, animated: true, completion: nil)
                    print(error?.localizedDescription ?? "Error")
                }
            }
            
        }
    
        alertController.addAction(createAction)
        createAction.isEnabled = false
        self.currentCreateAction = createAction
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        
        alertController.addTextField { (textField) -> Void in
            textField.placeholder = "New Member's Name"
            textField.addTarget(self, action: #selector(NiaClassViewController.classNameFieldDidChange(_:)) , for: UIControlEvents.editingChanged)
        }
        alertController.addTextField { (textField) -> Void in
            textField.placeholder = "EMail Address"
            textField.addTarget(self, action: #selector(NiaClassViewController.classAddressFieldDidChange(_:)) , for: UIControlEvents.editingChanged)
        }
        alertController.addTextField { (textField) -> Void in
            textField.placeholder = "Telephone Number"
            textField.addTarget(self, action: #selector(NiaClassViewController.classPhoneNumberFieldDidChange(_:)) , for: UIControlEvents.editingChanged)
        }
        
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    //Enable the create action of the alert only if textfield text is not empty
    func classNameFieldDidChange(_ textField:UITextField){
        self.currentCreateAction.isEnabled = (textField.text?.characters.count)! > 0
    }
    func classAddressFieldDidChange(_ textField:UITextField){
        self.currentCreateAction.isEnabled = (textField.text?.characters.count)! > 0
    }
    func classPhoneNumberFieldDidChange(_ textField:UITextField){
        self.currentCreateAction.isEnabled = (textField.text?.characters.count)! > 0
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (deleteAction, indexPath) -> Void in
            
            //Deletion will go here
            
            let memberToBeRemoved = self.members[indexPath.row]
            
            
        }
            
        return [deleteAction]
    }
}
