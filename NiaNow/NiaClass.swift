//
//  NiaClass
//  NiaNow
//
//  Created by David Brownstone on 6/4/17.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import Foundation
import Firebase

struct NiaClass {
    let key: String
    let name: String
    let addedByUser: String
    let originatorFullname:String
    var members:[String]
    let ref: DatabaseReference?
    
    init(name: String, addedByUser: String, originator: String, key: String = "") {
        self.key = key
        self.name = name
        self.addedByUser = addedByUser
        self.originatorFullname = originator
        self.members = []
        self.members.append("dummy")
        self.ref = nil
    }
    
    init(snapshot: DataSnapshot) {
        key = snapshot.key
        let snapshotValue = snapshot.value as! [String: AnyObject]
        name = snapshotValue["name"] as! String
        addedByUser = snapshotValue["addedByUser"] as! String
        originatorFullname = snapshotValue["originatorFullname"] as! String
        if snapshotValue["members"] != nil  {
            members = snapshotValue["members"] as! [String]
        } else {
            members = []
            members.append("dummy")
        }
        ref = snapshot.ref
    }
    
    func toAnyObject() -> Any {
        return [
            "name": name,
            "addedByUser": addedByUser,
            "originatorFullname": originatorFullname,
            "members": members
        ]
    }
    
    func numberOfUsers() -> Int {
        return self.members.count
    }
    
    mutating func addAMember(name:String) {
        if self.members.first == "dummy" {
            self.members = []
        }
        self.members.append(name)
    }
}
