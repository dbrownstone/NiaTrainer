//
//  LoginViewController.swift
//  NiaNow
//
//  Created by David Brownstone on 08/06/2017.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import UIKit
import Firebase

var token:String!

class LoginViewController: UIViewController, UITextFieldDelegate {

    // MARK: Constants
    let loginToNiaNow = "LoginNia"
    
    var keychain = KeychainSwift()

    var email = ""
    var password = ""
    var phone = ""
    var membersName = ""
    var uid = ""
    var rememberMe = false
    var memberExistsInDB = false
    
    // MARK: Outlets
    @IBOutlet weak var dataView:UIView!
    @IBOutlet weak var textFieldLoginEmail: UITextField!
    @IBOutlet weak var textFieldLoginPassword: UITextField!
//    @IBOutlet weak var textFieldLoginPhone: UITextField!
    @IBOutlet weak var checkbox: Checkbox!
    
    // MARK: Actions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,selector: #selector(handleCheckboxStatusChange), name: NSNotification.Name(rawValue: CheckboxStatusChangedNotification), object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func handleCheckboxStatusChange(notification:NSNotification) {
        let remember = ((notification.object! as! Checkbox).isChecked) as Bool
        self.rememberMe = remember
        keychain.set(remember, forKey:"rememberme")
        if !remember {
            email = ""
            password = ""
            membersName = ""
        } else {
            setKeyChainParameters()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.textFieldLoginEmail.delegate = self

        if let result = keychain.get("rememberme") {
            if result == "true" {
                rememberMe = true
                email = keychain.get("email")!
                textFieldLoginEmail.text! = email
                if email != keychain.get("email") {
                    textFieldLoginPassword.becomeFirstResponder()
                }
                password = keychain.get("password")!
                textFieldLoginPassword.text! = password
                if keychain.get("password") != nil {
                    textFieldLoginPassword.resignFirstResponder()
                }
            } else {
                rememberMe = false
                textFieldLoginEmail.becomeFirstResponder()
            }
            checkbox.setValue(rememberMe)
        } else {
            checkbox.setValue(false)
        }
    }
    
    private func setKeyChainParameters() {
        if self.keychain.get("email") != self.email {
            self.keychain.set(self.email, forKey: "email")
            self.keychain.set(self.password, forKey:"password")
            self.keychain.set(self.phone, forKey:"phone")
            self.keychain.set(self.membersName, forKey:"fullname")
        }
        self.keychain.set(String(self.rememberMe), forKey:"rememberme")
    }
    
    @IBAction func textFieldPrimaryActionTriggered(_ sender: Any) {
        loginDidTouch(sender as AnyObject)
    }
    
    private func authorize() {
        Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
            if let error = error {
                print(error.localizedDescription)
                let alert = UIAlertController(title: "Login Error",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "OK",
                                                 style: .default)
                alert.addAction(cancelAction)
                
                self.present(alert, animated: true, completion: nil)
            } else if let user = user {
                print(user.displayName ?? "")
                self.memberExistsInDB = true
                self.uid = user.uid
                loggedInMember = Member(email: self.email,  name: self.membersName, phone: self.phone, uid: self.uid, niaClass:"")
                self.updateUserProfile(fullname:self.membersName)
                token = Messaging.messaging().fcmToken
                print("FCM token: \(token ?? "")")
            }
        }
    }
    
    public func createNewUser() {
        Auth.auth().createUser(withEmail: email, password: password) { (user, error) in
            if let error = error {
                print(error.localizedDescription)
                self.showAlert(message: error.localizedDescription)
            }
            else if let user = user {
                print(user)
                var member = Member(email: self.email,  name: self.membersName, phone: self.phone, uid: UUID().uuidString, niaClass:"")
                member.authenticated = true
                let userRef = Database.database().reference(withPath: "users")
                let memberRef = userRef.child((self.membersName.lowercased()))
                memberRef.setValue(member.toAnyObject())
                loggedInMember = member
//                self.setKeyChainParameters()
                self.updateUserProfile(fullname:self.membersName)
            }
        }
//        let member = Member(email: email,  name: membersName, phone: phone, uid: (UUID().uuidString), niaClass: "")
//        let ref = Database.database().reference(withPath: "users")
//        let memberRef = ref.child((self.membersName.lowercased()))
//        memberRef.setValue(member.toAnyObject())
    }
    
    func showAlert(message:String) {
        let alert = UIAlertController(title: "Error",
                                      message: message,
                                      preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "OK",
                                         style: .default) {  action in
                                         self.signUpDidTouch(self)
        }
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    private func updateUserProfile(fullname:String) {
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = fullname
        
        // Commit profile changes to server
        changeRequest?.commitChanges() { (error) in
            
            if let error = error {
                print(error.localizedDescription)
                return
            } else {
                self.setKeyChainParameters()
                self.memberExistsInDB = true
                self.continueToNextScreen()
            }
        }
    }
    
    @IBAction func loginDidTouch(_ sender: AnyObject) {
        email = textFieldLoginEmail.text!
        password =  textFieldLoginPassword.text!
//        phone = textFieldLoginPhone.text!
        if password == "1A2B3C" {
            let alert = UIAlertController(title: "Change Password",
                                          message: "You should receive a password change request by email shortly upon touching OK",
                                          preferredStyle: .alert)
            let sendAction = UIAlertAction(title: "Save", style: .default) { action in
                Auth.auth().sendPasswordReset(withEmail: self.textFieldLoginEmail.text!, completion: { (error) in
                    
                    var title = ""
                    var message = ""
                    
                    if error != nil {
                        title = "Error!"
                        message = (error?.localizedDescription)!
                    } else {
                        title = "Success!"
                        message = "Password reset email sent."
                        self.textFieldLoginPassword.text = ""
                    }
                    
                    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    
                    let defaultAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                    alertController.addAction(defaultAction)
                    
                    self.present(alertController, animated: true, completion: nil)
                })
            }
            
            alert.addAction(sendAction)
            
            self.present(alert, animated: true, completion: nil)

        } else {
            let userRef = Database.database().reference(withPath:"users")
            
            userRef.observe(.value, with: { snapshot in
                if snapshot.childrenCount > 0 {
                    for aUser in snapshot.children {
                        let member = Member(snapshot: aUser as! DataSnapshot)
                        if self.email == member.email {
                            self.membersName = member.name
                            self.phone = member.phoneNo
                            self.keychain.set(self.membersName, forKey:"fullname")
                        }
                    }
                }
                self.setKeyChainParameters()
                self.authorize()
            })
        }
    }

    private func continueToNextScreen() {
        if memberExistsInDB {
            performSegue(withIdentifier: self.loginToNiaNow, sender: self.membersName)
        } else {
            signUpDidTouch("" as AnyObject)
        }
    }
    
    @IBAction func signUpDidTouch(_ sender: AnyObject) {
        let alert = UIAlertController(title: "Register",
                                      message: "Register",
                                      preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { action in
            self.membersName = "\(alert.textFields![0].text!) \(alert.textFields![1].text!)"
            self.email = alert.textFields![2].text!
            self.phone = alert.textFields![3].text!
            self.password = alert.textFields![4].text!
            self.createNewUser()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .default)
        
        alert.addTextField { textEmail in
            textEmail.placeholder = "Enter your first name"
        }
        
        alert.addTextField { textEmail in
            textEmail.placeholder = "Enter your last name"
        }
        
        alert.addTextField { textEmail in
            textEmail.placeholder = "Enter your email address"
        }
        
        alert.addTextField { textEmail in
            textEmail.placeholder = "Enter your phone number"
        }
        
        alert.addTextField { textPassword in
            textPassword.isSecureTextEntry = true
            textPassword.placeholder = "Enter your password"
        }
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                self.view.frame.origin.y -= keyboardSize.height
            }
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if textFieldLoginPassword.text == "" {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y != 0 {
                self.view.frame.origin.y += keyboardSize.height
            }
        }
    }
    // MARK: - Navigation
    
    @IBAction func unwindToVC1(segue:UIStoryboardSegue) {
//        email = ""
//        password = ""
//        membersName = ""
//        rememberMe = false
        textFieldLoginEmail.text = ""
        textFieldLoginPassword.text = ""
//        textFieldLoginPhone.text = ""
        checkbox.setValue(false)
        
//        self.keychain.set(self.email, forKey: "email")
//        self.keychain.set(self.password, forKey:"password")
//        self.keychain.set(self.phone, forKey:"phone")
//        self.keychain.set(self.membersName, forKey:"fullname")
//        self.keychain.set(String(self.rememberMe), forKey:"rememberme")
    }

    // MARK - UITextViewDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == textFieldLoginEmail {
            textFieldLoginPassword.becomeFirstResponder()
        }
        if textField == textFieldLoginPassword {
            textField.resignFirstResponder()
        }
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool
    {
        if textField == textFieldLoginEmail {
            textFieldLoginPassword.text = ""
//            textFieldLoginPhone.text = ""
            return true
        }
        return false;
    }
}
