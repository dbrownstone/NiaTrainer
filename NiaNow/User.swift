//
//  User.swift
//  NiaNow
//
//  Created by David Brownstone on 6/4/17.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import Foundation
import Firebase

struct User {
    let uid:String
    let fullname:String
    let email:String
    let phoneNumber:String
    let currentlyLoggedIn:Bool
    var participatingClassNames:[String]
    var authenticated = false
    
    init(authData: User) {
        uid = authData.uid
        email = authData.email
        fullname = ""
        phoneNumber = ""
        currentlyLoggedIn = false
        participatingClassNames = [String]()
    }
    
    
    init(uid: String, email: String, fullname: String, phone: String, authenticated: Bool) {
        self.uid = uid
        self.email = email
        self.fullname = fullname
        self.phoneNumber = phone
        self.currentlyLoggedIn = false
        self.authenticated = authenticated
        participatingClassNames = [String]()
    }
}
