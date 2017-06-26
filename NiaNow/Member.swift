//
//  member.swift
//  NiaNow
//
//  Created by David Brownstone on 13/06/2017.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import Foundation
import Firebase

struct Member {
    let key: String
    let email: String
    let name: String
    let phoneNo: String
    let uid: String
    var classes: [String]!
    var authenticated:Bool = false
    let ref: DatabaseReference?
    
    init(email: String, name: String, phone: String, uid: String, niaClass:String, key: String = "") {
        self.key = key
        self.email = email
        self.name = name
        self.phoneNo = phone
        self.uid = uid
        self.ref = nil
        self.classes = []
        self.classes.append(niaClass)
    }
    
    init(snapshot: DataSnapshot) {
        key = snapshot.key
        let snapshotValue = snapshot.value as! [String: AnyObject]
        email = snapshotValue["email"] as! String
        name = snapshotValue["name"] as! String
        phoneNo = snapshotValue["phoneNo"] as! String
        uid = snapshotValue["uid"] as! String
        if snapshot.hasChild("classes") {
            classes = snapshotValue["classes"] as! [String]
        } else {
            classes = []
        }
        if snapshot.hasChild("authenticated") {
            authenticated = snapshotValue["authenticated"] as! Bool
        } else {
            authenticated = false
        }
        ref = snapshot.ref
    }
    
    func toAnyObject() -> Any {
        return [
            "email": email,
            "name": name,
            "phoneNo": phoneNo,
            "classes": classes,
            "authenticated":authenticated,
            "uid": uid
        ]
    }
}
